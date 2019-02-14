
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
  static const columnCreateTimestamp = 'create_timestamp';
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
      '/add': _add,
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
            $columnCreateTimestamp INTEGER,
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
    String body = await getParams(request);
    // String body = await request.transform(utf8.decoder).join();
    var param = json.decode(body);
    var todo = param['todo'];

    database = await openDatabase(databasePath);
    var sql = '''DELETE FROM $tableName WHERE $columnId=${todo['id']}''';
    int count = await database.rawDelete(sql);
    await database.close();

    await _loadTodos(param['timestamp']);
  
    String todoData = json.encode(todos);
    request.response.write(todoData);
    request.response.close();
  }

  void _loadTodos([int timestamp]) async {
    var date = new DateTime.now();
    if(timestamp != null){
      date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    var year = date.year;
    var month = date.month;
    var day = date.day;
    var beginTimestamp = new DateTime(year, month, day).millisecondsSinceEpoch;
    var endTimestamp = new DateTime(year, month, day+1).millisecondsSinceEpoch;

    database = await openDatabase(databasePath);
    var sql = "select * from $tableName where $columnBeginTimestamp >= $beginTimestamp and $columnBeginTimestamp < $endTimestamp order by $columnDone asc";//desc
    var list = await database.rawQuery(sql);
    // await database.close();

    todos.clear();
    for(var item in list) {
      var todo = Todo.fromJson(item);
      todos.add(todo);
    }
  }
  // void addColumn() async{
  //   database = await openDatabase(databasePath);
  //   var sql = "alter table $tableName add column create_timestamp INTEGER";
  //   await database.execute(sql);
  //   print('done.......');
  // }

  void _todo_list(HttpRequest request) async{
    if(request.method != GET){
      _unsupportedMethod(request);
      return;
    }

    String body = await getParams(request);
    var timestamp = null;
    if(body.length > 0){
      timestamp = int.parse(json.decode(body)['timestamp']);
    }

    await _loadTodos(timestamp);
  
    String todoData = json.encode(todos);
    request.response.write(todoData);
    request.response.close();
  }

  _unsupportedMethod(HttpRequest request) {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    request.response.close();
  }

  void _add(HttpRequest request) async {
    if(request.method != 'POST') {
      _unsupportedMethod(request);
      return;
    }

    String body = await getParams(request);
    // String body = await request.transform(utf8.decoder).join();
    if(body != null) {
      var param = json.decode(body);
      var todo = Todo.create(param['msg'], param['timestamp']);
      
      await _storeTodos(todo);
      await _loadTodos(param['timestamp']);

      request.response.statusCode = HttpStatus.ok;
      var data = json.encode(todos);
      request.response.write(data);
    }else {
      request.response.statusCode = HttpStatus.badRequest;
    }
    request.response.close();
  }

  Future _storeTodos(Todo todo) async {
    print('_storeTodos insert:$todo'); 
    database = await openDatabase(databasePath);
    await database.insert(tableName, todo.toJson());
  }

  void _update(HttpRequest request) async {
    if(request.method != 'POST') {
      _unsupportedMethod(request);
      return;
    }
    
    String body = await getParams(request);
    // String body = await request.transform(utf8.decoder).join();
    if(body != null) {
      var param = json.decode(body);
      await _updateTodos(Todo.fromJson(param['todo']));
      await _loadTodos(param['timestamp']);

      request.response.statusCode = HttpStatus.ok;
      var data = json.encode(todos);
      request.response.write(data);
    }else {
      request.response.statusCode = HttpStatus.badRequest;
    }
    request.response.close();
  }

  Future _updateTodos(Todo todo) async {
    database = await openDatabase(databasePath);
    var sql = "update $tableName set done=${todo.done},finished_timestamp=${todo.finished_timestamp},update_timestamp=${todo.update_timestamp} where $columnId=${todo.id}";
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

   getParams(HttpRequest request) async{
    var params = null;
    if(request.method == 'POST') {
      params = await request.transform(utf8.decoder).join();
    }else if(request.method == 'GET') {
      var uri = request.uri.toString();
      var index = uri.indexOf('?');
      if(index > -1){
        Map<String, dynamic> param = {};
        var str = uri.substring(index+1);
        var arr = str.split('&');
        for (var i=0,len=arr.length; i<len;i++){
          var arr1 = arr[i].split('=');
          param[arr1[0]] = arr1[1];
        }
        params=json.encode(param);
      }
    }
    return params;
  }
}