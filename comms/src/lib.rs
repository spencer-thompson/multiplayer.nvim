/// from the on_lines nvim_buf_attach callback
pub struct Lines {
    bufnr: i32,
    changedtick: i32,
    first_line_changed: i32,
    last_line_changed: i32,
    last_line_updated: i32,
    previous_byte_count: i32,
    content: Vec<String>,
}

pub struct Edit {
    buffer: i32,
    timestamp: i32,
    start_row: i32,
    start_col: i32,
    end_row: i32,
    end_col: i32,
    content: Vec<String>,
}

// pub extern "C" fn
