class Todo {
  final String msg;             //todo 详情
  final int begin_timestamp;    //todo 需执行日期 时间戳
  final int finished_timestamp; //todo 完成时的 时间戳
  final int update_timestamp;   //todo 更新状态时 时间戳
  final int create_timestamp;   //todo 建立时的 时间戳
  final int done;               //todo 是否已完成  0:未完成  1:已完成
  final int id;

  Todo(this.msg, this.begin_timestamp, this.finished_timestamp, this.update_timestamp, this.create_timestamp, this.done, this.id);
  
  Todo.create(String msg, int timestamp)
    :msg = msg, begin_timestamp = timestamp, create_timestamp = DateTime.now().millisecondsSinceEpoch, finished_timestamp = null, 
    update_timestamp = DateTime.now().millisecondsSinceEpoch, done = 0, id=null;

  Todo.fromJson(Map<String, dynamic> json)
    :msg = json['msg'],begin_timestamp = json['begin_timestamp'],finished_timestamp = json['finished_timestamp'],update_timestamp = json['update_timestamp'],create_timestamp = json['create_timestamp'],done = json['done'],id = json['id'];

  Map<String, dynamic> toJson() {
    Map map = <String, dynamic> {
      "msg": msg,
      "begin_timestamp": begin_timestamp,
      "finished_timestamp": finished_timestamp,
      "update_timestamp": update_timestamp,
      "create_timestamp": create_timestamp,
      "done": done
    };
    if (id != null) {
      map['id'] = id;
    };
    return map;
  }

  @override
  String toString() {
    return 'Todo{id:$id,msg:$msg,begin_timestamp:$begin_timestamp,finished_timestamp:$finished_timestamp,update_timestamp:$update_timestamp,create_timestamp:$create_timestamp,done:$done}';
  }
}