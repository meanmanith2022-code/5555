// On native platforms we can use dart:io File. Export a factory named `createFile`.
import 'dart:io' as io;

io.File createFile(String path) => io.File(path);
