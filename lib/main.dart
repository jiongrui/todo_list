import 'dart:convert';
import 'package:flutter/material.dart';

import 'echo_client.dart';
import 'echo_server.dart';
import 'todo.dart';
import 'pages/add_todo.dart';
import 'toast.dart';
import 'color.dart';

HttpEchoServer _server;
HttpEchoClient _client;

int _timestamp = new DateTime.now().millisecondsSinceEpoch;
DateTime _date = new DateTime.now();

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'todo list',
      home: TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  TodoListScreen({Key key}) :super(key: key);

  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

var _title = '';
class _TodoListScreenState extends State<TodoListScreen> {
  final todoListKey = GlobalKey<_TodoListState>(debugLabel: 'todoListKey');

  @override
  void initState() {
    super.initState();
    setState((){
      _title = 'Todo List ' + new DateTime.now().toIso8601String().split('T')[0];;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: 
      Stack(children: [
        TodoList(key: todoListKey),
        Container(
          padding: EdgeInsets.only(right:15, bottom: 90),
          child: Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              onPressed: () async {
                selectDate(context);
              },
              heroTag: 'Select_Date',
              tooltip: 'Select Date',
              child: Icon(Icons.date_range),
            )
          )
        )
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          //今天以前的日期，不给添加todo
          if(todoListKey.currentState.isBeginToday() == false){
            Toast.toast(context, '过去不予新增todo！');
            return false;
          } 
          
          //跳转页面，等待页面返回参数
          final result = await Navigator.push(
              context, MaterialPageRoute(builder: (_) => AddTodoScreen()));

          if(_client == null || result == null) {
            return false;
          }
          print('result:$result');
          todoListKey.currentState.addTodo(result);
        },
        heroTag: 'Add_Todo',
        tooltip: 'Add Todo',
        child: Icon(Icons.add) 
      ),
      // backgroundColor: HexColor('#EE82EE')
    );
  }

  //日期选择器
  Future<Null> selectDate(BuildContext context) async {
    final DateTime picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: new DateTime(2019),
      lastDate: new DateTime(2050),
      initialDatePickerMode: DatePickerMode.day
    );

    if(picked != null){
      print('picked:$picked');
      _date = picked;
      _timestamp = picked.millisecondsSinceEpoch;
      todoListKey.currentState.getTodos();

      setState((){
        _title = 'Todo List ' + picked.toIso8601String().split('T')[0];
      });
    }
  }
}

class NotTodos extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('not todos!')
    );
  }
}


//listview

class TodoList extends StatefulWidget {
  TodoList({Key key}) : super(key: key);

  @override
  State createState() {
    return _TodoListState();
  }
}

//with WidgetsBindingObserver 监控 app操作状态
class _TodoListState extends State<TodoList> with WidgetsBindingObserver {
  final List<Todo> todos = [];

  Map<String, dynamic> param;

  @override
  void initState() {
    super.initState();

    const port = 6060;
    _server = HttpEchoServer(port);
    _server.start().then((_) {
      _client = HttpEchoClient(port);
      getTodos();
      WidgetsBinding.instance.addObserver(this);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    //监控app进入到后台和返回app的状态
      print('state:$state');
    // if(state == AppLifecycleState.paused) {
    //   var server = _server;
    //   _server = null;
    //   server?.close();
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: todos.length == 0 ? NotTodos() : ListView.builder(
        itemCount: todos.length,
        itemBuilder: (context, index) {
          var todo = todos[index];
          final subtitle = DateTime.fromMillisecondsSinceEpoch(todo.update_timestamp)
              .toLocal()
              .toIso8601String().split('.')[0].replaceAll(new RegExp(r'T'),' ');
          return CheckboxListTile(
            secondary: InkWell(
              onTap:() async{
                if(isToday(todo.begin_timestamp) == false){
                  Toast.toast(context, '非当天，不予更改！');
                  return false; //非当天
                } 

                param = {
                  'context': context,
                  'func': deleteTodo,
                  'todo': todo,
                  'title': '确定删除todo?'
                };
                showWarnDialog(param);
              },
              child:Icon(Icons.delete)
            ),
            // activeColor: Colors.grey[500],
            title: Text(todo.msg),
            subtitle: Text(subtitle),
            value: todo.done == 1,
            onChanged: (bool value) {
              if(isToday(todo.begin_timestamp) == false){
                Toast.toast(context, '非当天，不予更改！');
                return false; //非当天
              } 

              if(value == false){
                Toast.toast(context, '已完成，不可更改！');
                return false; //已选中
              } 

              var item = todo.toJson();
              var now_timestamp = new DateTime.now().millisecondsSinceEpoch;
              item['done'] = value ? 1 : 0;
              item['update_timestamp'] = now_timestamp;
              item['finished_timestamp'] = now_timestamp;
              todo = Todo.fromJson(item);
              param = {
                'context': context,
                'func': updateTodo,
                'title': '确定已完成?',
                'todo': todo
              };
              showWarnDialog(param);
            },
          );
        },
      )
    );
  }

  void getTodos() {
    _client.getTodos(_timestamp).then((list){
      resetTodos(list);
    });
  }

  void resetTodos(List<Todo> list) {
    setState((){
      todos.replaceRange(0, todos.length,list);
    });
  }

  void deleteTodo(Todo todo) async{
    param = {
      'todo': todo,
      'timestamp': _timestamp 
    };
    var list = await _client.delete(param);
    resetTodos(list);
  }

  void updateTodo(Todo todo) async{
    param = {
      'todo': todo,
      'timestamp': _timestamp 
    };
    var list = await _client.update(param);
    resetTodos(list);
  }

  void addTodo(String msg) async{
    param = {
      'msg': msg,
      'timestamp': _timestamp 
    };

    var list = await _client.add(param);
    if(list != null) {
      // todoListKey.currentState.addMessage(msg);
      resetTodos(list);
    }else {
      debugPrint('fail to send $msg');
    }
  }

  bool isToday(int begin_timestamp){
    var today = new DateTime.now();
    var year = today.year;
    var month = today.month;
    var day = today.day;
    var beginTimestamp = new DateTime(year, month, day).millisecondsSinceEpoch;
    var endTimestamp = new DateTime(year, month, day+1).millisecondsSinceEpoch; 

    if(begin_timestamp >= beginTimestamp && begin_timestamp < endTimestamp){
      return true;
    }
    return false;
  }

  bool isBeginToday() {
    var today = new DateTime.now();
    var year = today.year;
    var month = today.month;
    var day = today.day;
    var beginTimestamp = new DateTime(year, month, day).millisecondsSinceEpoch;

    if(_timestamp >= beginTimestamp){
      return true;
    }
    return false;
  }
}

Future<void> showWarnDialog(Map param) async {
  return showDialog<void>(
    context: param['context'],
    barrierDismissible: false, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(param['title']),
        // content: SingleChildScrollView(
        //   child: ListBody(
        //     children: <Widget>[
        //       Text('You will never be satisfied.'),
        //       Text('You\’re like me. I’m never satisfied.'),
        //     ],
        //   ),
        // ),
        actions: <Widget>[
          FlatButton(
            child: Text('取消'),
            onPressed: () {
              Navigator.of(param['context']).pop();
            },
          ),
          FlatButton(
            child: Text('确定'),
            onPressed: () {
              param['func'](param['todo']);
              Navigator.of(param['context']).pop();
            },
          ),
        ],
      );
    },
  );
}




