import 'dart:convert';

import '../config/relay_config.dart';
import '../models/gate_reply.dart';
import 'agate_log.dart';
import 'bolt_agent.dart';

/// Sends the flat config-body POST to the backend and parses the reply.
class ChannelDispatch {
  ChannelDispatch(this._agent);

  final BoltAgent _agent;

  Future<GateReply> send(Map<String, dynamic> body) async {
    final url = Uri.parse(AetherRelayConfig.relayEndpoint);
    try {
      final r = await _agent.post(
        url,
        body: jsonEncode(body),
        timeout: AetherRelayConfig.configTimeout,
      );
      agateLog(() => '[AGATE.disp] ${r.statusCode} ${r.body.length}B');
      // The backend uses HTTP 404 as a "no campaign for this bundle" signal
      // (still returns a valid `{ok:false, message:"No data"}` JSON body).
      // Treat 2xx AND that specific 404 shape as parseable so the router can
      // see `message` and commit the route to `native` — otherwise every
      // launch reruns the whole pipeline (§organic-recheck in the lessons).
      final ok2xx = r.statusCode >= 200 && r.statusCode < 300;
      final looksJson = r.body.trimLeft().startsWith('{');
      if (!ok2xx && !looksJson) return GateReply.denied;
      final parsed = await decodeJsonBody(r.body);
      if (parsed == null) return GateReply.denied;
      return GateReply.parse(parsed);
    } catch (e) {
      agateLog(() => '[AGATE.disp] error: $e');
      return GateReply.denied;
    }
  }
}
