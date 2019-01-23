import 'dart:convert';
import 'package:flutter/material.dart';

import 'echo_client.dart';
import 'echo_server.dart';
import 'todo.dart';

HttpEchoServer _server;
HttpEchoClient _client;

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
  var _timestamp = new DateTime.now().millisecondsSinceEpoch;
  var _date = new DateTime.now();

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
    return Stack(
      children:[
        ListView.builder(
        itemCount: todos.length,
        itemBuilder: (context, index) {
          var todo = todos[index];
          final subtitle = DateTime.fromMillisecondsSinceEpoch(todo.update_timestamp)
              .toLocal()
              .toIso8601String().split('.')[0].replaceAll(new RegExp(r'T'),' ');
          return CheckboxListTile(
            secondary: InkWell(
              onTap:() async{
                param = {
                  'context': context,
                  'func': deleteTodo,
                  'todo': todo,
                  'title': 'be sure to delete todo?'
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
              if(value == false) return false; //已选中

              if(isToday(todo.begin_timestamp) == false) return false; //非当天

              var item = todo.toJson();
              var now_timestamp = new DateTime.now().millisecondsSinceEpoch;
              item['done'] = value ? 1 : 0;
              item['update_timestamp'] = now_timestamp;
              item['finished_timestamp'] = now_timestamp;
              todo = Todo.fromJson(item);

              param = {
                'context': context,
                'func': updateTodo,
                'title': 'be sure to change todo status?',
                'todo': todo
              };
              showWarnDialog(param);
            },
          );
        },
      ),
      Container(
        child: todos.length == 0 ? NotTodos() : null 
      ),
      Container(
        padding: EdgeInsets.only(right:15, bottom: 90),
        child: Align(
          alignment: Alignment.bottomRight,
          child: FloatingActionButton(
            onPressed: () async {
              _selectDate(context);
            },
            heroTag: 'Select_Date',
            tooltip: 'Select Date',
            child: Icon(Icons.date_range),
          )
        )
      )
    ]);
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

  bool isToday(int begin_timestamp) {
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

  //日期选择器
  Future<Null> _selectDate(BuildContext context) async {
    final DateTime _picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: new DateTime(2019),
      lastDate: new DateTime(2050),
      initialDatePickerMode: DatePickerMode.day
    );

    if(_picked != null){
      print('_picked:$_picked');
      _date = _picked;
      _timestamp = _picked.millisecondsSinceEpoch;
      getTodos();
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

class TodoListScreen extends StatelessWidget {
  final todoListKey =
      GlobalKey<_TodoListState>(debugLabel: 'todoListKey');
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Todo List')),
      body: TodoList(key: todoListKey),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          //不是大于今天的日期，不给添加todo
          if(todoListKey.currentState.isBeginToday() == false) return false;
          
          //跳转页面，等待页面返回参数
          final result = await Navigator.push(
              context, MaterialPageRoute(builder: (_) => AddMessageScreen()));

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
    );
  }
}

class TodoForm extends StatefulWidget {
  @override
  State createState() {
    return _TodoFormState();
  }
}

class _TodoFormState extends State<TodoForm> {
  final editController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
    editController.clear();
    editController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              margin: EdgeInsets.only(right: 8),
              child: TextField(
                decoration: InputDecoration(
                    hintText: 'Input Todo',
                    contentPadding: EdgeInsets.all(0)),
                style: TextStyle(fontSize: 22, color: Colors.black54),
                controller: editController,
                autofocus: true,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              var value = editController.text.trim();
              if(value.length > 0) {
                Navigator.pop(context, editController.text);
              }
            },
            child: Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(5.0)),
                child: Text('Add')),
          )
        ],
      ),
    );
  }
}

class AddMessageScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Todo'),
      ),
      body: TodoForm(),
    );
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


