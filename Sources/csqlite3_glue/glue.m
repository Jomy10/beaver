@import CSQLite;

/// same as `sqlite3_db_config(db, SQLITE_DBCONFIG_RESET_DATABASE, x, y)`
int sqliteglue_db_config_reset_database(sqlite3* db, int x, int y) {
  return sqlite3_db_config(db, SQLITE_DBCONFIG_RESET_DATABASE, x, y);
}
