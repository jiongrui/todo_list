import 'dart:convert';
import 'package:flutter/material.dart';
import '../todo.dart';

class AddTodoScreen extends StatelessWidget {
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