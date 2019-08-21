import 'package:flutter/widgets.dart';

import 'package:graphql/client.dart';
import 'package:graphql/internal.dart';

import 'package:graphql_flutter/src/widgets/graphql_provider.dart';
import "dart:async";
import 'package:flutter/material.dart';
import './main.dart' show getGraphQLClient;
// import 'package:graphql/internal.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart' show CupertinoTextField;

typedef RunMutation = void Function(
  Map<String, dynamic> variables, {
  Object optimisticResult,
});

typedef MutationBuilder = Widget Function(
  RunMutation runMutation,
  QueryResult result,
);

typedef OnMutationCompleted = void Function(dynamic data);
typedef OnMutationUpdate = void Function(Cache cache, QueryResult result);

/// Builds a [Mutation] widget based on the a given set of [MutationOptions]
/// that streams [QueryResult]s into the [QueryBuilder].
class TestMutation extends StatefulWidget {
  const TestMutation({
    final Key key,
    @required this.options,
    @required this.builder,
    this.onCompleted,
    this.update,
  }) : super(key: key);

  final MutationOptions options;
  final MutationBuilder builder;
  final OnMutationCompleted onCompleted;
  final OnMutationUpdate update;

  @override
  TestMutationState createState() => TestMutationState();
}

class TestMutationState extends State<TestMutation> {
  GraphQLClient client;
  ObservableQuery observableQuery;

  WatchQueryOptions get _options => WatchQueryOptions(
        document: widget.options.document,
        variables: widget.options.variables,
        fetchPolicy: widget.options.fetchPolicy,
        errorPolicy: widget.options.errorPolicy,
        fetchResults: false,
        context: widget.options.context,
      );

  // TODO is it possible to extract shared logic into mixin
  void _initQuery() {
    client = getGraphQLClient();
    assert(client != null);

    observableQuery?.close(force: true);

    observableQuery = client.watchQuery(_options);
    print("""
    
===================================
UPDATED_QUERY QUERY: ${observableQuery.queryId}
===================================
""");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('didChangeDependencies');
    _initQuery();
  }

  @override
  void didUpdateWidget(TestMutation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // TODO @micimize - investigate why/if this was causing issues

    if (!observableQuery.options.areEqualTo(_options)) {
      _initQuery();
    }
  }

  MultiSourceResult runMutation(
    Map<String, dynamic> variables, {
    Object optimisticResult,
  }) {
    print("""

===================================
START: runMutation ================
===================================
""");
    final query = observableQuery;

    query.stream.first.then((val) =>
        val != null ? print("old result: " + val.timestamp.toString()) : null);
    final result = (query
          ..variables = variables
          ..options.optimisticResult = optimisticResult
        // ..onData(callbacks) // add callbacks to observable
        )
        .fetchResults();
    Future<QueryResult> net = result.networkResult;
    net.then((val) => val != null
        ? print(
            "new result:: RESULT: ${val.timestamp.toString()} QUERY: ${query.queryId}")
        : null);

    return result;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _initQuery();
  }

  @override
  Widget build(BuildContext context) {
    print('build: ' + observableQuery.queryId);
    return StreamBuilder<QueryResult>(
      // we give the stream builder a key so that
      // toggling mutations at the same place in the tree,
      // such as is done in the example, won't result in bugs
      // key: Key(observableQuery?.options?.toKey()),
      initialData: observableQuery?.latestResult ?? QueryResult(),
      stream: observableQuery?.stream,
      builder: (
        BuildContext buildContext,
        AsyncSnapshot<QueryResult> snapshot,
      ) {
        print(
            "used for build: RESULT:${snapshot?.data?.timestamp.toString()} QUERY: ${observableQuery.queryId}");
        return widget.builder(
          runMutation,
          snapshot.data,
        );
      },
    );
  }
}
