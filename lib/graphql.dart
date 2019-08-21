// import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:graphql/client.dart';

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
