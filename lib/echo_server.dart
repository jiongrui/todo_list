
import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'todo.dart';

class HttpEchoServer {
  static const GET = 'GET';
  static const POST = 'POST';

  static const tableName = 'todo_list';
  static const columnId = 'id';
  static const columnMsg = 'msg';
  static const columnBeginTimestamp = 'begin_timestamp';
  static const columnFinishedTimestamp = 'finished_timestamp';
  static const columnUpdateTimestamp = 'update_timestamp';
  static const columnDone = 'done';

  final int port;
  HttpServer httpServer;
  Database database;
  String databasePath;

  Map<String, void Function(HttpRequest)> routes;

  final List<Todo> todos = [];

  HttpEchoServer(this.port){
    _initRoutes();
  }

  void _initRoutes() {
    routes = {
      '/todo_list': _todo_list,
      '/echo': _echo,
      '/update': _update,
      '/delete': _delete
    };
  }

  Future start() async {
    await _initDatabase();

    httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

    return httpServer.listen((request) {
      final path = request.uri.path;
      final handler = routes[path];
      if(handler != null) {
        handler(request);
      }else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
      }
    });
  }

  Future _initDatabase() async {
    databasePath = await getDatabasesPath() + '/todo.db';
    database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, verson) async {
        var sql='''
          CREATE TABLE $tableName (
            $columnId INTEGER PRIMARY KEY,
            $columnMsg TEXT,
            $columnBeginTimestamp INTEGER,
            $columnFinishedTimestamp INTEGER,
            $columnUpdateTimestamp INTEGER,
            $columnDone INTEGER
          )
        ''';
        await db.execute(sql);
        print('todo_list table created');
      }
    );
  }

  Future _delete(HttpRequest request) async {
    if(request.method != 'POST') {
      _unsupportedMethod(request);
      return;
    }

    String body = await request.transform(utf8.decoder).join();
    var id = json.decode(body);

    database = await openDatabase(databasePath);
    var sql = '''DELETE FROM $tableName WHERE $columnId=$id''';
    int count = await database.rawDelete(sql);
    await database.close();

    await _loadTodos();
  
    String todoData = json.encode(todos);
    request.response.write(todoData);
    request.response.close();
  }

  Future _loadTodos() async {
    database = await openDatabase(databasePath);
    var sql = "select * from $tableName order by $columnBeginTimestamp desc";
    var list = await database.rawQuery(sql);
    // await database.close();

    todos.clear();
    for(var item in list) {
      var todo = Todo.fromJson(item);
      todos.add(todo);
    }
  }

  void _todo_list(HttpRequest request) async{
    if(request.method != GET){
      _unsupportedMethod(request);
      return;
    }
    await _loadTodos();
  
    String todoData = json.encode(todos);
    request.response.write(todoData);
    request.response.close();
  }

  _unsupportedMethod(HttpRequest request) {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    request.response.close();
  }

  void _echo(HttpRequest request) async {
    if(request.method != 'POST') {
      _unsupportedMethod(request);
      return;
    }

    String body = await request.transform(utf8.decoder).join();
    if(body != null) {
      var todo = Todo.create(body);
      
      await _storeTodos(todo);
      await _loadTodos();

      request.response.statusCode = HttpStatus.ok;
      var data = json.encode(todos);
      request.response.write(data);
    }else {
      request.response.statusCode = HttpStatus.badRequest;
    }
    request.response.close();
  }

  Future<bool> _storeTodos(Todo msg) async {
    print('_storeTodos insert:$msg'); 
    database = await openDatabase(databasePath);
    await database.insert(tableName, msg.toJson());
  }

  void _update(HttpRequest request) async {
    if(request.method != 'POST') {
      _unsupportedMethod(request);
      return;
    }
    
    String body = await request.transform(utf8.decoder).join();
    if(body != null) {
      await _updateTodos(body);
      await _loadTodos();

      request.response.statusCode = HttpStatus.ok;
      var data = json.encode(todos);
      request.response.write(data);
    }else {
      request.response.statusCode = HttpStatus.badRequest;
    }
    request.response.close();
  }

  Future<bool> _updateTodos(String body) async {
    var todo = json.decode(body);

    database = await openDatabase(databasePath);
    var sql = "update $tableName set done=${todo["done"]} where $columnId=${todo["id"]}";
    await database.execute(sql);
    await database.close();
  }

  void close() async {
    var server =httpServer;
    httpServer = null;
    await server?.close();

    var db = database;
    database = null;
    db?.close();
  }
}