import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../network/api_client.dart';

class SseEvent {
  final String event;
  final String data;
  final String? id;

  SseEvent({required this.event, required this.data, this.id});

  Map<String, dynamic>? get dataAsJson {
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String get dataAsString => data;
}

class SseClient {
  SseClient._();

  static Stream<SseEvent> connect(
    String path, {
    Map<String, dynamic>? data,
    CancelToken? cancelToken,
  }) {
    final controller = StreamController<SseEvent>();

    ApiClient.instance.dio.post(
      path,
      data: data,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    ).then((response) {
      final stream = response.data as ResponseBody;
      String buffer = '';
      String? currentEvent;
      String? currentData;
      String? currentId;

      void resetState() {
        currentEvent = null;
        currentData = null;
        currentId = null;
      }

      void emitCurrentEvent() {
        if (currentEvent != null && currentData != null) {
          controller.add(SseEvent(
            event: currentEvent!,
            data: currentData!,
            id: currentId,
          ));
        }
      }

      void processLine(String line) {
        if (line.isEmpty) {
          // Empty line = event boundary
          emitCurrentEvent();
          resetState();
          return;
        }

        if (line.startsWith(':')) {
          // Comment, ignore
          return;
        }

        final colonIdx = line.indexOf(':');
        if (colonIdx == -1) {
          // Field name with no value
          return;
        }

        final field = line.substring(0, colonIdx);
        var value = line.substring(colonIdx + 1);
        if (value.startsWith(' ')) value = value.substring(1);

        switch (field) {
          case 'event':
            currentEvent = value;
            break;
          case 'data':
            if (currentData != null) {
              currentData = '$currentData\n$value';
            } else {
              currentData = value;
            }
            break;
          case 'id':
            currentId = value;
            break;
          case 'retry':
            // Could be used for reconnection, ignored for now
            break;
        }
      }

      stream.stream.listen(
        (chunk) {
          buffer += utf8.decode(chunk, allowMalformed: true);
          // Process complete lines
          while (buffer.contains('\n')) {
            final idx = buffer.indexOf('\n');
            final line = buffer.substring(0, idx);
            buffer = buffer.substring(idx + 1);
            processLine(line);
          }
        },
        onDone: () {
          // Process remaining buffer
          if (buffer.isNotEmpty) processLine(buffer);
          emitCurrentEvent();
          controller.close();
        },
        onError: (e) {
          controller.addError(e);
          controller.close();
        },
      );
    }).catchError((e) {
      controller.addError(e);
      controller.close();
    });

    return controller.stream;
  }
}
