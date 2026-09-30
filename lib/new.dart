import 'package:flutter/material.dart';

void main() {
  runApp(const NewApp());
}

class NewApp extends StatefulWidget {
  const NewApp({super.key});

  @override
  State<NewApp> createState() => _NewAppState();
}

List<String> todos = ['me ', 'you', 'them'];

class _NewAppState extends State<NewApp> {
final TextEditingController todoEditor = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("welcome")),
        body: ListView.builder(itemCount: todos.length, 
        itemBuilder : (context , index ){
          return Card(child: ListTile(title: Text(todos[index]),),);
        }),
        floatingActionButton: FloatingActionButton(onPressed: (){setState(() {
          todos.add("new task");
          
        });}, ),
      ),
    
    );
  }
}
