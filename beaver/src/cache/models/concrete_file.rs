use log::trace;
use ormlite::Model;
use sqlx::{SqliteConnection, Type, TypeInfo};
use sqlx::sqlite::SqliteTypeInfo;
use uuid::Uuid;

#[derive(Model, Debug, Clone)]
pub struct ConcreteFile {
    #[ormlite(primary_key)]
    pub context: String,
    pub filename: String,
    pub check_id: Uuid,
}

impl ConcreteFile {
    pub fn new(context: &str, filename: &str, check_id: Uuid) -> crate::Result<Self> {
        Ok(ConcreteFile {
            context: context.to_string(),
            filename: filename.to_string(),
            check_id
        })
    }

    pub async fn create_if_not_exists(conn: &mut SqliteConnection) -> Result<(), sqlx::Error> {
        let str_typeinfo: SqliteTypeInfo = <String as sqlx::Type::<sqlx::Sqlite>>::type_info();
        let uuid_typeinfo: SqliteTypeInfo = <Uuid as sqlx::Type::<sqlx::Sqlite>>::type_info();

        let res = sqlx::query(&format!("
CREATE TABLE IF NOT EXISTS concrete_file (
    context {} PRIMARY KEY,
    filename {},
    check_id {}
)
            ",
            str_typeinfo.name(),
            str_typeinfo.name(),
            uuid_typeinfo.name())
        ).execute(conn).await;

        res.map(|val| {
            trace!("{:?}", val);

            ()
        })
    }
}
