class Todo {
  final String msg;
  final int begin_timestamp;
  final int finished_timestamp;
  final int update_timestamp;
  final int done;
  final int id;

  Todo(this.msg, this.begin_timestamp, this.finished_timestamp, this.update_timestamp, this.done, this.id);
  
  Todo.create(String msg)
    :msg = msg, begin_timestamp = DateTime.now().millisecondsSinceEpoch, finished_timestamp = null, 
    update_timestamp = DateTime.now().millisecondsSinceEpoch, done = 0, id=null;

  Todo.fromJson(Map<String, dynamic> json)
    :msg = json['msg'],begin_timestamp = json['begin_timestamp'],finished_timestamp = json['finished_timestamp'],update_timestamp = json['update_timestamp'],done = json['done'],id = json['id'];

  Map<String, dynamic> toJson() {
    Map map = <String, dynamic> {
      "msg": msg,
      "begin_timestamp": begin_timestamp,
      "finished_timestamp": finished_timestamp,
      "update_timestamp": update_timestamp,
      "done": done
    };
    if (id != null) {
      map['id'] = id;
    };
    return map;
  }

  @override
  String toString() {
    return 'Todo{id:$id,msg:$msg,begin_timestamp:$begin_timestamp,finished_timestamp:$finished_timestamp,update_timestamp:$update_timestamp,done:$done}';
  }
}