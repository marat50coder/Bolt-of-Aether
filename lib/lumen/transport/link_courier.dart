import 'dart:convert';

import '../config/link_config.dart';
import '../models/link_reply.dart';
import 'link_agent.dart';
import 'nova_log.dart';

/// Sends the flat config-body POST to the backend and parses the reply.
class LinkCourier {
  LinkCourier(this._agent);

  final LinkAgent _agent;

  Future<LinkReply> send(Map<String, dynamic> body) async {
    final url = Uri.parse(LinkConfig.relayEndpoint);
    try {
      final r = await _agent.post(
        url,
        body: jsonEncode(body),
        timeout: LinkConfig.configTimeout,
      );
      novaLog(() => '[NOVA.mail] ${r.statusCode} ${r.body.length}B');
      // The backend also uses HTTP 404 as a "no campaign for this bundle"
      // signal, and still returns a valid `{ok:false, message:"No data"}`
      // JSON body. Treat both 2xx AND a 404 with that shape as parseable
      // so the router can see `message` and commit the route to `native`
      // — otherwise every launch reruns the entire pipeline.
      final ok2xx = r.statusCode >= 200 && r.statusCode < 300;
      final looksJson = r.body.trimLeft().startsWith('{');
      if (!ok2xx && !looksJson) return LinkReply.denied;
      final parsed = await decodeJsonBody(r.body);
      if (parsed == null) return LinkReply.denied;
      return LinkReply.parse(parsed);
    } catch (e) {
      novaLog(() => '[NOVA.mail] error: $e');
      return LinkReply.denied;
    }
  }
}
