import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:pin_code_text_field/pin_code_text_field.dart';

import 'package:graphql/internal.dart';

import 'package:flutter/material.dart';

import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoTextField;
import './mutation.dart';

final HttpLink _httpLink = HttpLink(
  uri: 'http://localhost:4000/graphql',
);

final AuthLink _authLink = AuthLink(
  getToken: () async => null,
);

final Link _link = _authLink.concat(_httpLink);

GraphQLClient _client;

GraphQLClient getGraphQLClient() {
  _client ??= GraphQLClient(
    link: _link,
    cache: new InMemoryCache(),
  );

  return _client;
}

ValueNotifier<GraphQLClient> client = ValueNotifier(
  getGraphQLClient(),
);
void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: client,
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(),
        // initialRoute: 'test',
        routes: {
          'test': (context) => MyHomePage(),
        },
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  final focusNode = FocusNode();
  final controller = StreamController<int>();
  ObservableQuery observableQuery;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    observableQuery?.close();
    observableQuery = _client.watchQuery(WatchQueryOptions(
      fetchPolicy: FetchPolicy.networkOnly,
      document: """

                mutation LoginRequestSms(\$phoneNumber: String!) {
                  Onboard {
                    requestSMSCode(
                      phoneNumber: \$phoneNumber
                    )
                  }
                }
                """, // this is the mutation string you just created
    ));
  }

  void _incrementCounter() {
    // setState(() {
    //   // This call to setState tells the Flutter framework that something has
    //   // changed in this State, which causes it to rerun the build method below
    //   // so that the display can reflect the updated values. If we changed
    //   // _counter without calling setState(), then the build method would not be
    //   // called again, and so nothing would appear to happen.
    //   _counter++;
    // });
  }
  runQuery(
    Map<String, dynamic> variables, {
    Object optimisticResult,
  }) {
    return (observableQuery
          ..variables = variables
          ..options.optimisticResult = optimisticResult)
        .fetchResults();
  }

  buildMutationBody(context, runMutation, result) {
    return Container(
      constraints: BoxConstraints(minWidth: double.infinity),
      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      child: Column(
        children: <Widget>[
          result != null ? Text(result.hasErrors.toString()) : Text("false"),
          FlatButton(
            child: Text("Click Me"),
            onPressed: () {
              // FocusScope.of(context).requestFocus(focusNode);
              setState(() {});
              runMutation({'phoneNumber': '+15555555555'});
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("widget.title"),
      ),
      body: Column(
        children: <Widget>[
          Container(
            child: FlatButton(
              child: Text("Navigate To Self"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyHomePage()),
                );
                // runMutation({'phoneNumber': '+15555555555'});
              },
            ),
          ),
          Mutation(
            options: MutationOptions(
              fetchPolicy: FetchPolicy.networkOnly,
              // variables: {'phoneNumber': '+15555555555'},
              document: """

                mutation LoginRequestSms(\$phoneNumber: String!) {
                  Onboard {
                    requestSMSCode(
                      phoneNumber: \$phoneNumber
                    )
                  }
                }
                """, // this is the mutation string you just created
            ),
            builder: (runMutation, result) {
              return buildMutationBody(context, runMutation, result);
            },
          ),
          TestMutation(
            options: MutationOptions(
              fetchPolicy: FetchPolicy.networkOnly,
              // variables: {'phoneNumber': '+15555555555'},
              document: """

                mutation LoginRequestSms(\$phoneNumber: String!) {
                  Onboard {
                    requestSMSCode(
                      phoneNumber: \$phoneNumber
                    )
                  }
                }
                """, // this is the mutation string you just created
            ),
            builder: (runMutation, result) {
              return buildMutationBody(context, runMutation, result);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    observableQuery?.close();
  }
}
