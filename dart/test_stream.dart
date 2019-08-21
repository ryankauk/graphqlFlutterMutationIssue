// import 'dart:async' show StreamController;
import 'dart:async' show StreamController, StreamSubscription;
import 'package:meta/meta.dart';
import 'package:async/async.dart' show StreamZip, StreamGroup;
// import 'package:graphql/client.dart' show  FetchPolicy;
import 'package:graphql/src/core/query_result.dart';
import 'package:graphql/src/core/query_options.dart';
import '../lib/graphql.dart' show getGraphQLClient;
import 'package:graphql/internal.dart' show ObservableQuery;

final _options = WatchQueryOptions(
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
);

class StreamId {
  ObservableQuery query;
  QueryResult result;
  StreamId({@required this.query, this.result});
}

class ObservableData {
  ObservableQuery query;
  Stream<StreamId> stream;
  ObservableData({@required this.query, this.stream});
}

var observableQuery = getGraphQLClient().watchQuery(_options);
final observables = Set<ObservableData>();

final streamGroup = StreamGroup<StreamId>();

runMutation() {
  return (observableQuery..variables = {'phoneNumber': '+5555555555'})
      .fetchResults();
}

updateQuery() {
  final newQuery = getGraphQLClient().watchQuery(_options);
  final ObData = ObservableData(
      query: newQuery,
      stream: newQuery.stream.map((val) {
        return StreamId(query: newQuery, result: val);
      }));
  observables.add(ObData);
  streamGroup.add(ObData.stream);
  observableQuery = newQuery;
}

StreamSubscription subscription;
watchForCleanup() {
  print('watch');
  if (subscription != null) return;

  subscription = streamGroup.stream.listen((val) {
    print("ID: ${val.query.queryId} LOADING: ${val.result.loading}");
    if (val.query.queryId != observableQuery.queryId) {
      if (val.result.loading == false) {
        observables.remove(val.query);
      }
    } else {
      observables
          .where((data) => data.query.queryId != observableQuery.queryId)
          .forEach((val) {
        streamGroup.remove(val.stream);
      });
      observables
          .removeWhere((data) => data.query.queryId != observableQuery.queryId);
    }
  });
}

void main() {
  updateQuery();
  watchForCleanup();
  print('here');

  runMutation();

  Future.delayed(Duration(milliseconds: 100)).then((val) {
    print('remove');
    updateQuery();
    runMutation();
  });
}
