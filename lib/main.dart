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
      home: MessageListScreen(),
    );
  }
}

class MessageList extends StatefulWidget {
  MessageList({Key key}) : super(key: key);

  @override
  State createState() {
    return _MessageListState();
  }
}

class _MessageListState extends State<MessageList> with WidgetsBindingObserver {
  final List<Todo> todos = [];

  Map<String, dynamic> param;

  @override
  void initState() {
    super.initState();

    const port = 6060;
    _server = HttpEchoServer(port);
    _server.start().then((_) {
      _client = HttpEchoClient(port);
      _client.getTodos().then((list){
        setState((){
          todos.addAll(list);
        });
      });
      WidgetsBinding.instance.addObserver(this);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state == AppLifecycleState.paused) {
      var server = _server;
      _server = null;
      server?.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: todos.length,
      itemBuilder: (context, index) {
        var todo = todos[index];
        final subtitle = DateTime.fromMillisecondsSinceEpoch(todo.begin_timestamp)
            .toLocal()
            .toIso8601String().split('.')[0];
        return CheckboxListTile(
          secondary: InkWell(
            onTap:() async{
              param = {
                'context': context,
                'func': deleteTodo,
                'todo': todo,
                'title': 'be sure to delete todo?'
              };
              _neverSatisfied(param);
            },
            child:Icon(Icons.delete)
          ),
          title: Text(todo.msg),
          subtitle: Text(subtitle),
          value: todo.done == 1,
          onChanged: (bool value) {
            var item = todo.toJson();
            item['done'] = value ? 1 : 0;
            todo = Todo.fromJson(item);

            param = {
              'context': context,
              'func': updateTodo,
              'title': 'be sure to change todo status?',
              'todo': todo
            };
            _neverSatisfied(param);
            // var item = todo.toJson();
            // item['done'] = value ? 1 : 0;
            // todo = Todo.fromJson(item);
            // setState(() { 
            //   todos.replaceRange(index, index+1, [todo]);
            // });
            // _client.update(json.encode(todo));
          },
        );
      },
    );
  }

  void resetTodos(List<Todo> list) {
    setState((){
      todos.replaceRange(0,todos.length,list);
    });
  }

  void deleteTodo(Todo todo) async{
    var list = await _client.delete(todo.id);
    resetTodos(list);
  }

  void updateTodo(Todo todo) async{
    // setState(() { 
    //   todos.replaceRange(index, index+1, [todo]);
    // });
    var list = await _client.update(json.encode(todo));
    resetTodos(list);
  }
}

class MessageListScreen extends StatelessWidget {
  final messageListKey =
      GlobalKey<_MessageListState>(debugLabel: 'messageListKey');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Todo List')),
      body: MessageList(key: messageListKey),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
              context, MaterialPageRoute(builder: (_) => AddMessageScreen()));

          if(_client == null) {
            return;
          }
          print('result:$result');
          var list = await _client.send(result);

          if(list != null) {
            // messageListKey.currentState.addMessage(msg);
            messageListKey.currentState.resetTodos(list);
          }else {
            debugPrint('fail to send $result');
          }
        },
        tooltip: 'Add Todo',
        child: Icon(Icons.add),
      ),
    );
  }
}

class MessageForm extends StatefulWidget {
  @override
  State createState() {
    return _MessageFormState();
  }
}

class _MessageFormState extends State<MessageForm> {
  final editController = TextEditingController();

  @override
  void dispose() {
    super.dispose();
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
              debugPrint('send:${editController.text}');
              Navigator.pop(context, editController.text);
            },
            child: Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(5.0)),
                child: Text('Send')),
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
      body: MessageForm(),
    );
  }
}

Future<void> _neverSatisfied(Map param) async {
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
