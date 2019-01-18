import 'dart:async';
import 'dart:convert'; //引入json API

import 'package:http/http.dart' as http;

import 'todo.dart';

class HttpEchoClient {
  final int port;
  final String host;

  HttpEchoClient(this.port): host = 'http://localhost:$port';

  Future send(String todo) async {
    final response = await http.post(host + '/echo', body:todo);
    if(response.statusCode == 200) {
      // Map<String, dynamic> todoJson = json.decode(response.body);
      // var todo = Todo.fromJson(todoJson);
      // return todo;
      return _decodeTodos(response.body);
    }else {
      return null;
    }
  }

  Future update(String todo) async {
    final response = await http.post(host + '/update', body:todo);
    if(response.statusCode == 200) {
      return _decodeTodos(response.body);
    }else {
      return null;
    }
  }

  Future delete(int id) async {
    final response = await http.post(host + '/delete', body:json.encode(id));
    if(response.statusCode == 200) {
      // print('response.body:${response.body}');
      return _decodeTodos(response.body);
    }else {
      return null;
    }
  }

  Future<List<Todo>> getTodos() async {
    try{
      final response = await http.get(host + '/todo_list');
      if(response.statusCode == 200){
        return _decodeTodos(response.body);
      }
    }catch(e) {
      print('getTodos:$e');
    }
    return null;
  }

  List<Todo> _decodeTodos(String response) {
    var todos = json.decode(response);
    var list = <Todo>[];
    for(var todoJson in todos) {
      list.add(Todo.fromJson(todoJson));
    }
    return list;
  }

  // void dealResponse(s response){

  // }
}