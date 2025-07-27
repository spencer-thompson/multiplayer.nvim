/// The ALPN for dumbpipe.
///
/// It is basically just passing data through 1:1, except that the connecting
/// side will send a fixed size handshake to make sure the stream is created.
pub const ALPN: &[u8] = b"MULTIPLAYER.NVIM";

/// The handshake to send when connecting.
///
/// The side that calls open_bi() first must send this handshake, the side that
/// calls accept_bi() must consume it.
pub const HANDSHAKE: [u8; 4] = *b"nvim";
//
// from the on_lines nvim_buf_attach callback
// pub struct Lines {
//     bufnr: i32,
//     changedtick: i32,
//     first_line_changed: i32,
//     last_line_changed: i32,
//     last_line_updated: i32,
//     previous_byte_count: i32,
//     content: Vec<String>,
// }
//
// pub struct Edit {
//     buffer: i32,
//     timestamp: i32,
//     start_row: i32,
//     start_col: i32,
//     end_row: i32,
//     end_col: i32,
//     content: Vec<String>,
// }
use std::net::TcpListener;
use std::os::raw::c_int;

#[no_mangle]
pub extern "C" fn get_open_port() -> c_int {
    // match TcpListener::bind("127.0.0.1:0") {
    //     Ok(listener) => listener.local_addr().unwrap().port() as c_int,
    //     Err(_) => -1,
    // }

    let listener = TcpListener::bind("127.0.0.1:0").expect("Could not bind");
    let port = listener.local_addr().unwrap().port() as c_int;

    // Drop listener for reuse in another program
    drop(listener);

    port
}
