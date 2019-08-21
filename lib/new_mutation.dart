import 'package:flutter/widgets.dart';

import 'package:graphql/client.dart';
import 'package:graphql/internal.dart';
import 'package:async/async.dart' show StreamGroup;
import 'package:graphql_flutter/src/widgets/graphql_provider.dart';
import "dart:async";
import 'package:flutter/material.dart';

import 'dart:async';

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
class Mutation extends StatefulWidget {
  const Mutation({
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
  MutationState createState() => MutationState();
}

class StreamId {
  ObservableQuery query;
  QueryResult result;
  StreamId({@required this.query, this.result});
}

class MutationState extends State<Mutation> {
  GraphQLClient client;
  ObservableQuery observableQuery;
  final streamGroup = StreamGroup<StreamId>.broadcast();
  // final observables = Set<ObservableData>();
  final observables = Map<ObservableQuery, Stream<StreamId>>();
  StreamSubscription subscription;

  WatchQueryOptions get _options => WatchQueryOptions(
        document: widget.options.document,
        variables: observableQuery?.options?.variables ??
            widget.options.variables, //observableQuery?.options?.variables ??
        fetchPolicy: widget.options.fetchPolicy,
        errorPolicy: widget.options.errorPolicy,
        fetchResults: false,
        context: widget.options.context,
      );

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    subscription?.cancel();
    subscription = null;
    observableQuery?.close();
  }

  // TODO is it possible to extract shared logic into mixin

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('didChangeDependencies');

    _initQuery();
  }

  @override
  void didUpdateWidget(Mutation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // TODO @micimize - investigate why/if this was causing issues

    if (!observableQuery.options.areEqualTo(_options)) {
      _initQuery();
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    // _initQuery();
    watchForCleanup();
  }

  _initQuery() {
    client = GraphQLProvider.of(context).value;
    assert(client != null);
    final newQuery = client.watchQuery(_options);

    final stream = newQuery.stream.map((val) {
      return StreamId(query: newQuery, result: val);
    });
    // observables.add(obData);
    observables[newQuery] = stream;
    streamGroup.add(stream);
    observableQuery = newQuery;
  }

  watchForCleanup() {
    if (subscription != null) return;

    subscription = streamGroup.stream.listen((val) {
      if (val.query.queryId != observableQuery.queryId) {
        // if result is from old query, wait for result to be loaded then remove
        if (val.result.loading == false) {
          final stream = observables[val.query];

          remove(stream, val.query);
        }
      } else {
        // if result is for newest query then cleanup all other queries
        final filteredMap = Map.fromIterable(
            observables.keys
                .where((val) => val.queryId != observableQuery.queryId),
            key: (k) => k as ObservableQuery,
            value: (k) => observables[k]);

        filteredMap.forEach((query, stream) {
          remove(stream, query);
        });
      }
    });
  }

  remove(Stream<StreamId> stream, ObservableQuery query) {
    streamGroup.remove(stream);
    observables.remove(query);
    query.close();
  }

  OnData get onCompleted {
    if (widget.onCompleted != null) {
      return (QueryResult result) {
        if (!result.loading && !result.optimistic) {
          widget.onCompleted(result.data);
        }
      };
    }
    return null;
  }

  /// The optimistic cache layer id `update` will write to
  /// is a "child patch" of the default optimistic patch
  /// created by the query manager
  String get _patchId => '${observableQuery.queryId}.update';

  /// apply the user's patch
  void _optimisticUpdate(QueryResult result) {
    final Cache cache = client.cache;
    final String patchId = _patchId;
    // this is also done in query_manager, but better safe than sorry
    assert(cache is OptimisticCache,
        "can't optimisticly update non-optimistic cache");
    (cache as OptimisticCache).addOptimisiticPatch(patchId, (Cache cache) {
      widget.update(cache, result);
      return cache;
    });
  }

  // optimistic patches will be cleaned up by the query_manager
  // cleanup is handled by heirarchical optimism -
  // as in, because our patch id is prefixed with '${observableQuery.queryId}.',
  // it will be discarded along with the observableQuery.queryId patch
  // TODO this results in an implicit coupling with the patch id system
  OnData get update {
    if (widget.update != null) {
      // dereference all variables that might be needed if the widget is disposed
      final Cache cache = client.cache;
      final OnMutationUpdate widgetUpdate = widget.update;
      final OnData optimisticUpdate = _optimisticUpdate;

      // wrap update logic to handle optimism
      void updateOnData(QueryResult result) {
        if (result.optimistic) {
          return optimisticUpdate(result);
        } else {
          widgetUpdate(cache, result);
        }
      }

      return updateOnData;
    }
    return null;
  }

  // callbacks will be called against each result in the stream,
  // which should then rebroadcast queries with the appropriate optimism
  Iterable<OnData> get callbacks =>
      <OnData>[onCompleted, update].where(notNull);

  MultiSourceResult runMutation(
    Map<String, dynamic> variables, {
    Object optimisticResult,
  }) {
    return (observableQuery
          ..variables = variables
          ..options.optimisticResult = optimisticResult
          ..onData(callbacks) // add callbacks to observable
        )
        .fetchResults();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StreamId>(
      // we give the stream builder a key so that
      // toggling mutations at the same place in the tree,
      // such as is done in the example, won't result in bugs
      key: Key(observableQuery?.options?.toKey()),
      initialData: StreamId(
          query: observableQuery,
          result: observableQuery?.latestResult ?? QueryResult()),
      stream: streamGroup.stream,
      builder: (
        BuildContext buildContext,
        AsyncSnapshot<StreamId> snapshot,
      ) {
        return widget.builder(
          runMutation,
          snapshot.data.result,
        );
      },
    );
  }
}
