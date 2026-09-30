import 'package:flutter/material.dart';

void main() {
  runApp(const MyAppBasic());
}

class MyAppBasic extends StatelessWidget {
  const MyAppBasic({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Todo List")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(child: ListTile(title: Text("bankai"))),
              Card(child: ListTile(title: Text("yokoso"))),
              Card(child: ListTile(title: Text('sakakamano sekhai'))),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Color.fromARGB(255, 76, 166, 240),
          onPressed: () => print("button pressed"),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
