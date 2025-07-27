use anyhow::Context;
use clap::{Parser, Subcommand};
// use comms::NodeTicket;
use iroh::{endpoint::Connecting, Endpoint, NodeAddr, SecretKey};
use iroh_base::ticket::NodeTicket;
use std::{
    io,
    net::{SocketAddr, SocketAddrV4, SocketAddrV6, ToSocketAddrs},
    str::FromStr,
};
use tokio::{
    io::{AsyncRead, AsyncWrite},
    select,
};
use tokio_util::sync::CancellationToken;

const HANDSHAKE: [u8; 4] = *b"nvim";
const ALPN: &[u8] = b"MULTIPLAYER.NVIM";

#[derive(Parser, Debug)]
pub struct Args {
    #[clap(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    Host(HostArgs),
    Join(JoinArgs),
}

#[derive(Parser, Debug)]
pub struct CommonArgs {
    /// The IPv4 address that magicsocket will listen on.
    ///
    /// If None, defaults to a random free port, but it can be useful to specify a fixed
    /// port, e.g. to configure a firewall rule.
    #[clap(long, default_value = None)]
    pub magic_ipv4_addr: Option<SocketAddrV4>,

    /// The IPv6 address that magicsocket will listen on.
    ///
    /// If None, defaults to a random free port, but it can be useful to specify a fixed
    /// port, e.g. to configure a firewall rule.
    #[clap(long, default_value = None)]
    pub magic_ipv6_addr: Option<SocketAddrV6>,

    /// A custom ALPN to use for the magicsocket.
    ///
    /// This is an expert feature that allows dumbpipe to be used to interact
    /// with existing iroh protocols.
    ///
    /// When using this option, the connect side must also specify the same ALPN.
    /// The listen side will not expect a handshake, and the connect side will
    /// not send one.
    ///
    /// Alpns are byte strings. To specify an utf8 string, prefix it with `utf8:`.
    /// Otherwise, it will be parsed as a hex string.
    // #[clap(long)]
    // pub custom_alpn: Option<String>,

    /// The verbosity level. Repeat to increase verbosity.
    #[clap(short = 'v', long, action = clap::ArgAction::Count)]
    pub verbose: u8,
}

#[derive(Parser, Debug)]
pub struct HostArgs {
    #[clap(flatten)]
    pub common: CommonArgs,

    #[clap(long)]
    pub addr: String,
}

#[derive(Parser, Debug)]
pub struct JoinArgs {
    #[clap(long)]
    pub addr: String,

    pub ticket: NodeTicket,

    #[clap(flatten)]
    pub common: CommonArgs,
}

/// Copy from a reader to a quinn stream.
///
/// Will send a reset to the other side if the operation is cancelled, and fail
/// with an error.
///
/// Returns the number of bytes copied in case of success.
async fn copy_to_quinn(
    mut from: impl AsyncRead + Unpin,
    mut send: quinn::SendStream,
    token: CancellationToken,
) -> io::Result<u64> {
    // tracing::trace!("copying to quinn");
    tokio::select! {
        res = tokio::io::copy(&mut from, &mut send) => {
            let size = res?;
            send.finish()?;
            Ok(size)
        }
        _ = token.cancelled() => {
            // send a reset to the other side immediately
            send.reset(0u8.into()).ok();
            Err(io::Error::other("cancelled"))
        }
    }
}

/// Copy from a quinn stream to a writer.
///
/// Will send stop to the other side if the operation is cancelled, and fail
/// with an error.
///
/// Returns the number of bytes copied in case of success.
async fn copy_from_quinn(
    mut recv: quinn::RecvStream,
    mut to: impl AsyncWrite + Unpin,
    token: CancellationToken,
) -> io::Result<u64> {
    tokio::select! {
        res = tokio::io::copy(&mut recv, &mut to) => {
            Ok(res?)
        },
        _ = token.cancelled() => {
            recv.stop(0u8.into()).ok();
            Err(io::Error::other("cancelled"))
        }
    }
}

/// Get the secret key or generate a new one.
///
/// Print the secret key to stderr if it was generated, so the user can save it.
fn get_or_create_secret() -> anyhow::Result<SecretKey> {
    match std::env::var("IROH_SECRET") {
        Ok(secret) => SecretKey::from_str(&secret).context("invalid secret"),
        Err(_) => {
            // eprintln!("Need to use IROH_SECRET")
            panic!("Need environment variable: IROH_SECRET")
            // let key = SecretKey::generate(rand::rngs::OsRng);
            // eprintln!(
            //     "using secret key {}",
            //     data_encoding::HEXLOWER.encode(&key.to_bytes())
            // );
            // Ok(key)
        }
    }
}

fn cancel_token<T>(token: CancellationToken) -> impl Fn(T) -> T {
    move |x| {
        token.cancel();
        x
    }
}

/// Bidirectionally forward data from a quinn stream and an arbitrary tokio
/// reader/writer pair, aborting both sides when either one forwarder is done,
/// or when control-c is pressed.
async fn forward_bidi(
    from1: impl AsyncRead + Send + Sync + Unpin + 'static,
    to1: impl AsyncWrite + Send + Sync + Unpin + 'static,
    from2: quinn::RecvStream,
    to2: quinn::SendStream,
) -> anyhow::Result<()> {
    let token1 = CancellationToken::new();
    let token2 = token1.clone();
    let token3 = token1.clone();
    let forward_from_stdin = tokio::spawn(async move {
        copy_to_quinn(from1, to2, token1.clone())
            .await
            .map_err(cancel_token(token1))
    });
    let forward_to_stdout = tokio::spawn(async move {
        copy_from_quinn(from2, to1, token2.clone())
            .await
            .map_err(cancel_token(token2))
    });
    let _control_c = tokio::spawn(async move {
        tokio::signal::ctrl_c().await?;
        token3.cancel();
        io::Result::Ok(())
    });
    forward_to_stdout.await??;
    forward_from_stdin.await??;
    Ok(())
}

/// Listen on a tcp port and forward incoming connections to a magicsocket.
async fn join_tcp(args: JoinArgs) -> anyhow::Result<()> {
    let addrs = args
        .addr
        .to_socket_addrs()
        .context(format!("invalid host string {}", args.addr))?;
    let secret_key = get_or_create_secret()?;
    let mut builder = Endpoint::builder().alpns(vec![]).secret_key(secret_key);
    if let Some(addr) = args.common.magic_ipv4_addr {
        builder = builder.bind_addr_v4(addr);
    }
    if let Some(addr) = args.common.magic_ipv6_addr {
        builder = builder.bind_addr_v6(addr);
    }
    let endpoint = builder.bind().await.context("unable to bind magicsock")?;
    // tracing::info!("tcp listening on {:?}", addrs);
    let tcp_listener = match tokio::net::TcpListener::bind(addrs.as_slice()).await {
        Ok(tcp_listener) => tcp_listener,
        Err(cause) => {
            panic!("error binding tcp socket to address: {cause}");
            // tracing::error!("error binding tcp socket to {:?}: {}", addrs, cause);
            // return Ok(());
        }
    };
    async fn handle_tcp_accept(
        next: io::Result<(tokio::net::TcpStream, SocketAddr)>,
        addr: NodeAddr,
        endpoint: Endpoint,
        alpn: &[u8],
    ) -> anyhow::Result<()> {
        let (tcp_stream, tcp_addr) = next.context("error accepting tcp connection")?;
        let (tcp_recv, tcp_send) = tcp_stream.into_split();
        // tracing::info!("got tcp connection from {}", tcp_addr);
        let remote_node_id = addr.node_id;
        let connection = endpoint
            .connect(addr, alpn)
            .await
            .context(format!("error connecting to {remote_node_id}"))?;
        let (mut magic_send, magic_recv) = connection
            .open_bi()
            .await
            .context(format!("error opening bidi stream to {remote_node_id}"))?;
        // send the handshake unless we are using a custom alpn
        // when using a custom alpn, evertyhing is up to the user
        // the connecting side must write first. we don't know if there will be something
        // on stdin, so just write a handshake.
        magic_send.write_all(&HANDSHAKE).await?;
        forward_bidi(tcp_recv, tcp_send, magic_recv, magic_send).await?;
        anyhow::Ok(())
    }
    let addr = args.ticket.node_addr();
    loop {
        // also wait for ctrl-c here so we can use it before accepting a connection
        let next = tokio::select! {
            stream = tcp_listener.accept() => stream,
            _ = tokio::signal::ctrl_c() => {
                eprintln!("got ctrl-c, exiting");
                break;
            }
        };
        let endpoint = endpoint.clone();
        let addr = addr.clone();
        let alpn = ALPN.to_vec();
        tokio::spawn(async move {
            if let Err(cause) = handle_tcp_accept(next, addr, endpoint, &alpn).await {
                panic!("Error handling connection: {cause}")
                // log error at warn level
                //
                // we should know about it, but it's not fatal
                // tracing::warn!("error handling connection: {}", cause);
            }
        });
    }
    Ok(())
}

/// Listen on a magicsocket and forward incoming connections to a tcp socket.
async fn host_tcp(args: HostArgs) -> anyhow::Result<()> {
    let addrs = match args.addr.to_socket_addrs() {
        Ok(addrs) => addrs.collect::<Vec<_>>(),
        // Err(e) => snafu::whatever!("invalid host string {}: {}", args.host, e),
        Err(e) => panic!("{}", e),
    };
    let secret_key = get_or_create_secret()?;
    let mut builder = Endpoint::builder()
        .alpns(vec![ALPN.to_vec()])
        .secret_key(secret_key);
    if let Some(addr) = args.common.magic_ipv4_addr {
        builder = builder.bind_addr_v4(addr);
    }
    if let Some(addr) = args.common.magic_ipv6_addr {
        builder = builder.bind_addr_v6(addr);
    }
    let endpoint = builder.bind().await?;
    // wait for the endpoint to figure out its address before making a ticket
    endpoint.home_relay().initialized().await?;
    let node_addr = endpoint.node_addr().await?;
    let mut short = node_addr.clone();
    let ticket = NodeTicket::new(node_addr);
    short.direct_addresses.clear();
    let short = NodeTicket::new(short);

    // print the ticket on stderr so it doesn't interfere with the data itself
    //
    // note that the tests rely on the ticket being the last thing printed
    eprintln!("address: {}", args.addr);
    // eprintln!("To connect, use e.g.:");
    eprintln!("ticket: {ticket}");
    if args.common.verbose > 0 {
        eprintln!("alternative: {short}");
    }
    // tracing::info!("node id is {}", ticket.node_addr().node_id);
    // tracing::info!("derp url is {:?}", ticket.node_addr().relay_url);

    // handle a new incoming connection on the magic endpoint
    async fn handle_magic_accept(
        connecting: Connecting,
        addrs: Vec<std::net::SocketAddr>,
    ) -> anyhow::Result<()> {
        let connection = connecting.await.context("error accepting connection")?;
        // let remote_node_id = &connection.remote_node_id()?;
        // tracing::info!("got connection from {}", remote_node_id);
        let (s, mut r) = connection
            .accept_bi()
            .await
            .context("error accepting stream")?;
        // tracing::info!("accepted bidi stream from {}", remote_node_id);
        // read the handshake and verify it
        let mut buf = [0u8; HANDSHAKE.len()];
        r.read_exact(&mut buf).await?;
        // snafu::ensure_whatever!(buf == HANDSHAKE, "invalid handshake");
        let connection = tokio::net::TcpStream::connect(addrs.as_slice())
            .await
            .context(format!("error connecting to {addrs:?}"))?;
        let (read, write) = connection.into_split();
        forward_bidi(read, write, r, s).await?;
        Ok(())
    }

    loop {
        let incoming = select! {
            incoming = endpoint.accept() => incoming,
            _ = tokio::signal::ctrl_c() => {
                eprintln!("got ctrl-c, exiting");
                break;
            }
        };
        let Some(incoming) = incoming else {
            break;
        };
        let Ok(connecting) = incoming.accept() else {
            break;
        };
        let addrs = addrs.clone();
        tokio::spawn(async move {
            if let Err(cause) = handle_magic_accept(connecting, addrs).await {
                panic!("Error handling connection: {cause}");
                // log error at warn level
                //
                // we should know about it, but it's not fatal
                // tracing::warn!("error handling connection: {}", cause);
            }
        });
    }
    Ok(())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // tracing_subscriber::fmt::init();
    let args = Args::parse();
    let res = match args.command {
        Commands::Host(args) => host_tcp(args).await,
        Commands::Join(args) => join_tcp(args).await,
    };
    match res {
        Ok(()) => std::process::exit(0),
        Err(e) => {
            eprintln!("error: {e}");
            std::process::exit(1)
        }
    }
}
