library dinamico_dart;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:dinamico_dart/src/text_form_builder.dart';
import 'package:json_dynamic_widget/json_dynamic_widget.dart';
import 'package:json_dynamic_widget_plugin_material_icons/json_dynamic_widget_plugin_material_icons.dart';
import 'package:json_dynamic_widget_plugin_svg/json_dynamic_widget_plugin_svg.dart';

class Dinamico {
  static final Map<String, StreamController<http.Response>>
      _pathToStreamController = {};

  Dinamico(JsonWidgetRegistry registry, String host, Map identifierToAction) {
    WidgetsFlutterBinding.ensureInitialized();
    JsonMaterialIconsPlugin.bind(registry);
    JsonSvgPlugin.bind(registry);

    registry.registerFunctions({
      'simplePrintMessage': ({args, required registry}) => () {
            var message = 'This is a simple print message';
            if (args?.isEmpty == false) {
              for (var arg in args!) {
                message += ' $arg';
              }
            }
            // ignore: avoid_print
            print(message);
          },
      'httpAction': ({args, required registry}) => () async {
            var response = await http.post(
              Uri.parse(host + '/dinamico/http-action'),
              headers: <String, String>{
                'Content-Type': 'application/json; charset=UTF-8',
              },
              body: json.encode(args?[0]),
            );

            if (response.body == "") {
              return;
            }

            var parsedJson = json.decode(response.body);

            if (parsedJson is! List) {
              return;
            }

            Map identifierToActionDefault = {
              'set-value': (value) => (value as Map).forEach((key, value) {
                    registry.setValue(key, value);
                  }),
            };

            Map _identifierToAction = {
              ...identifierToActionDefault,
              ...identifierToAction,
            };

            for (var el in parsedJson) {
              var identifier = el[0] as String;
              var value = el[1];

              var action = _identifierToAction[identifier];
              action(value);
            }
          },
    });

    registry.registerCustomBuilder(
      TextFormFieldBuilder.type,
      const JsonWidgetBuilderContainer(
          builder: TextFormFieldBuilder.fromDynamic),
    );
  }

  final streamFunction = ((path) {
    late final StreamController<http.Response> controller;
    late http.Response _lastResponse;
    bool _hasLastResponse = false;

    if (_pathToStreamController[path] != null) {
      _pathToStreamController[path]?.close();
    }

    controller = StreamController<http.Response>(
      onListen: () async {
        while (!controller.isClosed) {
          var response = await http.get(Uri.parse(path));
          if (!_hasLastResponse || _lastResponse.body != response.body) {
            if (!controller.isClosed) {
              controller.add(response);
            }
            _hasLastResponse = true;
            _lastResponse = response;
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      },
    );

    _pathToStreamController[path] = controller;
    return controller.stream;
  });

  Widget build(BuildContext context, String path) {
    return StreamBuilder(
      builder: (context, AsyncSnapshot<http.Response> snapshot) {
        var body = snapshot.data?.body;
        if (snapshot.hasData && body != null) {
          var widgetJson = json.decode(body);
          var widget = JsonWidgetData.fromDynamic(
            widgetJson,
          );
          if (widget != null) {
            return widget.build(context: context);
          } else {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        } else {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
      stream: streamFunction(path),
    );
  }
}
