mod atoms;
mod document;
mod error;
mod index;
mod query;
mod schema;
mod search;
mod snippet;

/// Wraps a NIF body in `catch_unwind` to convert panics into `Err(String)`
/// instead of crashing the BEAM VM. Every NIF that calls into tantivy
/// should use this macro.
macro_rules! catch_nif_panic {
    ($($body:tt)*) => {
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| { $($body)* })) {
            Ok(result) => result,
            Err(panic_info) => {
                let msg = if let Some(s) = panic_info.downcast_ref::<String>() {
                    format!("NIF panic: {}", s)
                } else if let Some(s) = panic_info.downcast_ref::<&str>() {
                    format!("NIF panic: {}", s)
                } else {
                    "NIF panic: unknown error".to_string()
                };
                Err(msg)
            }
        }
    };
}

pub(crate) use catch_nif_panic;

rustler::init!("Elixir.SearchTantivy.Native");
