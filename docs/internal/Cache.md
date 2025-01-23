```mermaid
erDiagram

File {
	int id
	string filename
	int mtime
	int size
	int ino
	int mode
	int uid
	int gid
}

CSourceFile {
	int fileID
	int configID
	int targetID
	int objectType
}

Configuration {
  int id
	string mode
}

Target {
	int id
	int project
	int target
}

GlobalConfiguration {
	%% The Beaver buildId; regenerated on every build
  int buildID
  %% A hash computed from the environment variables
  int env
}

DependencyFile {
	inf fileID
	int configID
	int targetID
	%% The artifact this dependency is linked to
	int artifactType
}

CustomFile {
	int fileID
	string context
}

File ||--|| CSourceFile: fileID
CSourceFile }o--|| Configuration: configID
CSourceFile }o--|| Target: targetID

File ||--|| DependencyFile: fileID
DependencyFile }o--|| Configuration: configID
DependencyFile }o--|| Target: targetID

File ||--|| CustomFile: fileID
```