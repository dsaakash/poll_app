import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Poll Creation App',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [PollCreationScreen(), PollListScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.create),
            label: 'Create Poll',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Poll List',
          ),
        ],
      ),
    );
  }
}

class PollCreationScreen extends StatefulWidget {
  @override
  _PollCreationScreenState createState() => _PollCreationScreenState();
}

class _PollCreationScreenState extends State<PollCreationScreen> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _statementController = TextEditingController();
  bool _isAnonymous = false;
  String _pollType = 'text'; // Default poll type is set to 'text'
  List<TextEditingController> _optionControllers = [TextEditingController(), TextEditingController()];

  Future<void> createPoll() async {
    final url = Uri.parse('https://dev.stance.live/api/test-polls/');
    List<String> options = _optionControllers.map((controller) => controller.text).toList();

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'topic': _topicController.text,
          'statement': _statementController.text,
          'is_anonymous': _isAnonymous.toString(),
          'poll_type': _pollType,
          'text_options': options.join(','),
        }),
      );

      final responseBody = json.decode(response.body);
      if (responseBody['code'] == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Poll created successfully.')));
        // Clear the fields after successful creation
        _topicController.clear();
        _statementController.clear();
        _optionControllers.forEach((controller) => controller.clear());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${responseBody['reason']}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred while creating the poll. Error: $e')));
    }
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('A poll must have at least two options.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create a Poll')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _topicController,
              decoration: InputDecoration(hintText: 'Enter the topic'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _statementController,
              decoration: InputDecoration(hintText: 'Enter your statement here'),
            ),
            SizedBox(height: 10),
            SwitchListTile(
              title: Text('Anonymous'),
              value: _isAnonymous,
              onChanged: (bool value) {
                setState(() {
                  _isAnonymous = value;
                });
              },
            ),
            ..._optionControllers.map((controller) {
              int index = _optionControllers.indexOf(controller);
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(hintText: 'Option ${index + 1}'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline),
                    onPressed: () => _removeOption(index),
                  ),
                ],
              );
            }).toList(),
            ElevatedButton(
              onPressed: _addOption,
              child: Icon(Icons.add),
            ),
            ElevatedButton(
              onPressed: createPoll,
              child: Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _topicController.dispose();
    _statementController.dispose();
    _optionControllers.forEach((controller) => controller.dispose());
    super.dispose();
  }
}

class PollListScreen extends StatefulWidget {
  @override
  _PollListScreenState createState() => _PollListScreenState();
}

class _PollListScreenState extends State<PollListScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<dynamic> _polls = [];
  bool _isFetching = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchPolls();
  }

  Future<void> _fetchPolls() async {
    if (_isFetching) return;
    setState(() {
      _isFetching = true;
    });

    var url = Uri.parse('https://dev.stance.live/api/test-polls?page=$_page');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> newPolls = json.decode(response.body)['data'] ?? [];
        if (newPolls.isNotEmpty) {
          setState(() {
            _polls.addAll(newPolls);
            _page++; // Prepare for next page
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load polls.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    } finally {
      setState(() {
        _isFetching = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isFetching) {
      _fetchPolls();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Polls List')),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _polls.length + (_isFetching ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _polls.length) {
            var poll = _polls[index];
            return ListTile(
              title: Text(poll['topic'] ?? 'No title'),
              subtitle: Text(poll['statement'] ?? 'No statement'),
            );
          } else {
            return Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
