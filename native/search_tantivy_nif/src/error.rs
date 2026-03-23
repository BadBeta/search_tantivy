#[derive(thiserror::Error, Debug)]
pub enum TantivyNifError {
    #[error("schema error: {0}")]
    Schema(String),

    #[error("index error: {0}")]
    Index(#[from] tantivy::TantivyError),

    #[error("query parse error: {0}")]
    QueryParse(#[from] tantivy::query::QueryParserError),

    #[error("invalid field: {0}")]
    InvalidField(String),

    #[error("io error: {0}")]
    Io(#[from] std::io::Error),

    #[error("directory error: {0}")]
    Directory(#[from] tantivy::directory::error::OpenDirectoryError),

    #[error("lock contention — retry")]
    LockFail,

    #[error("{0}")]
    Other(String),
}

impl From<TantivyNifError> for rustler::Error {
    fn from(e: TantivyNifError) -> Self {
        rustler::Error::Term(Box::new(e.to_string()))
    }
}
