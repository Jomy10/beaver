import SQLite

@attached(extension, conformances: CacheEntry, names: arbitrary)
macro CacheEntry(name: String? = nil) = #externalMacro(module: "CacheMacros", type: "CacheEntryMacro")

@attached(peer)
macro PrimaryKey(_ type: SQLite.PrimaryKey) = #externalMacro(module: "CacheMacros", type: "PrimaryKeyMacro")

@attached(peer)
macro PrimaryKey(_ type: Bool) = #externalMacro(module: "CacheMacros", type: "PrimaryKeyMacro")
