import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final TextEditingController todoEditor = TextEditingController();
  List<String> todos = ["Bankai", "Yokoso", "Sakakamano Sekhai"];
  void showAddTodoDialog() {
    setState(() {
      todos.add("Dialog Opened");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      home: Scaffold(
        appBar: AppBar(title: const Text("Todo List")),

        body: ListView.builder(
          itemCount: todos.length,

          itemBuilder: (context, index) {
            return Card(child: ListTile(title: Text(todos[index])));
          },
        ),

        floatingActionButton: FloatingActionButton(
          onPressed: showAddTodoDialog,

          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
