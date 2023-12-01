import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_toastr/flutter_toastr.dart';
import 'package:network_proxy/network/util/request_rewrite.dart';
import 'package:network_proxy/ui/component/multi_window.dart';
import 'package:network_proxy/ui/component/utils.dart';
import 'package:network_proxy/ui/component/widgets.dart';
import 'package:network_proxy/ui/desktop/toolbar/setting/rewite/rewrite_replace.dart';

class RequestRewriteWidget extends StatefulWidget {
  final int windowId;
  final RequestRewrites requestRewrites;

  const RequestRewriteWidget({super.key, required this.windowId, required this.requestRewrites});

  @override
  State<StatefulWidget> createState() {
    return RequestRewriteState();
  }
}

class RequestRewriteState extends State<RequestRewriteWidget> {
  late ValueNotifier<bool> enableNotifier;

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(onKeyEvent);
    enableNotifier = ValueNotifier(widget.requestRewrites.enabled == true);
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      print("call.method: ${call.method}");
      if (call.method == 'reloadRequestRewrite') {
        await widget.requestRewrites.reloadRequestRewrite();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(onKeyEvent);
    super.dispose();
  }

  void onKeyEvent(RawKeyEvent event) async {
    if (event.isKeyPressed(LogicalKeyboardKey.exit) && Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    if ((event.isKeyPressed(LogicalKeyboardKey.metaLeft) || event.isControlPressed) &&
        event.isKeyPressed(LogicalKeyboardKey.keyW)) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
        return;
      }
      RawKeyboard.instance.removeListener(onKeyEvent);
      WindowController.fromWindowId(widget.windowId).close();
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Theme.of(context).dialogBackgroundColor,
        appBar: AppBar(
            title: const Text("请求重写", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            toolbarHeight: 34,
            centerTitle: true),
        body: Padding(
            padding: const EdgeInsets.only(left: 15, right: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(
                    width: 280,
                    child: ValueListenableBuilder(
                        valueListenable: enableNotifier,
                        builder: (_, bool v, __) {
                          return SwitchListTile(
                              contentPadding: const EdgeInsets.only(left: 2),
                              title: const Text('是否启用请求重写'),
                              dense: true,
                              value: enableNotifier.value,
                              onChanged: (value) {
                                enableNotifier.value = value;
                                MultiWindow.invokeRefreshRewrite(Operation.refresh);
                              });
                        })),
                Expanded(
                    child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("添加", style: TextStyle(fontSize: 12)),
                      onPressed: add,
                    ),
                    // const SizedBox(width: 20),
                    // FilledButton.icon(
                    //   icon: const Icon(Icons.input_rounded, size: 18),
                    //   style: ElevatedButton.styleFrom(padding: const EdgeInsets.only(left: 20, right: 20)),
                    //   onPressed: add,
                    //   label: const Text("导入"),
                    // )
                  ],
                )),
                const SizedBox(width: 15)
              ]),
              const SizedBox(height: 10),
              RequestRuleList(widget.requestRewrites),
            ])));
  }

  void add([int currentIndex = -1]) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return RuleAddDialog(
              currentIndex: currentIndex, rule: currentIndex >= 0 ? widget.requestRewrites.rules[currentIndex] : null);
        }).then((value) {
      if (value != null) setState(() {});
    });
  }
}

///请求重写规则添加对话框
class RuleAddDialog extends StatefulWidget {
  final int currentIndex;
  final RequestRewriteRule? rule;

  const RuleAddDialog({super.key, this.currentIndex = -1, this.rule});

  @override
  State<StatefulWidget> createState() {
    return _RuleAddDialogState();
  }
}

class _RuleAddDialogState extends State<RuleAddDialog> {
  late ValueNotifier<bool> enableNotifier;
  late RequestRewriteRule rule;

  @override
  void initState() {
    super.initState();
    rule = widget.rule ?? RequestRewriteRule(true, url: '', type: RuleType.responseReplace);
    enableNotifier = ValueNotifier(rule.enabled == true);
  }

  @override
  void dispose() {
    enableNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    GlobalKey formKey = GlobalKey<FormState>();

    return AlertDialog(
        scrollable: true,
        title: const Text("添加请求重写规则", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        content: Container(
            constraints: const BoxConstraints(minWidth: 350),
            child: Form(
                key: formKey,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ValueListenableBuilder(
                          valueListenable: enableNotifier,
                          builder: (_, bool enable, __) {
                            return SwitchListTile(
                                contentPadding: const EdgeInsets.only(left: 0),
                                title: const Text('是否启用', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                value: enable,
                                onChanged: (value) => enableNotifier.value = value);
                          }),
                      const SizedBox(height: 5),
                      textField('名称:', rule.name, '请输入名称'),
                      const SizedBox(height: 10),
                      textField('URL:', rule.url, 'http://www.example.com/api/*'),
                      const SizedBox(height: 10),
                      Row(children: [
                        const SizedBox(width: 60, child: Text('行为:')),
                        SizedBox(
                            width: 100,
                            height: 33,
                            child: DropdownButtonFormField<RuleType>(
                                value: rule.type,
                                decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.only(left: 7, right: 7),
                                    focusedBorder: focusedBorder(),
                                    border: const OutlineInputBorder()),
                                items: RuleType.values
                                    .map((e) => DropdownMenuItem(
                                        value: e, child: Text(e.label, style: const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    rule.type = val!;
                                  });
                                })),
                        const SizedBox(width: 10),
                        TextButton(onPressed: () => showEdit(rule), child: const Text("点击编辑"))
                      ])
                    ]))),
        actions: [
          FilledButton(
              child: const Text("保存"),
              onPressed: () async {
                if ((formKey.currentState as FormState).validate()) {
                  (formKey.currentState as FormState).save();

                  rule.updatePathReg();
                  rule.enabled = enableNotifier.value;
                  if (widget.currentIndex >= 0) {
                    (await RequestRewrites.instance).rules[widget.currentIndex] = rule;
                    MultiWindow.invokeRefreshRewrite(Operation.update, index: widget.currentIndex, rule: rule);
                  } else {
                    (await RequestRewrites.instance).addRule(rule);
                    MultiWindow.invokeRefreshRewrite(Operation.add, rule: rule);
                  }
                  if (mounted) {
                    Navigator.of(context).pop(rule);
                  }
                }
              }),
          ElevatedButton(
              child: const Text("关闭"),
              onPressed: () {
                Navigator.of(context).pop();
              })
        ]);
  }

  void showEdit(RequestRewriteRule rule) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => RewriteReplaceDialog(rule: rule),
    ).then((value) {
      if (value != null) setState(() {});
    });
  }

  Widget textField(String label, dynamic value, String hint) {
    return Row(children: [
      SizedBox(width: 60, child: Text(label)),
      Expanded(
          child: TextFormField(
        initialValue: value,
        style: const TextStyle(fontSize: 14),
        validator: (val) => val?.isNotEmpty == true ? null : "",
        onChanged: (val) => value = val,
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            contentPadding: const EdgeInsets.all(10),
            errorStyle: const TextStyle(height: 0, fontSize: 0),
            focusedBorder: focusedBorder(),
            isDense: true,
            border: const OutlineInputBorder()),
      ))
    ]);
  }

  InputBorder focusedBorder() {
    return OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2));
  }
}

///请求重写规则列表
class RequestRuleList extends StatefulWidget {
  final RequestRewrites requestRewrites;

  RequestRuleList(this.requestRewrites) : super(key: GlobalKey<_RequestRuleListState>());

  @override
  State<RequestRuleList> createState() => _RequestRuleListState();
}

class _RequestRuleListState extends State<RequestRuleList> {
  int selected = -1;
  late List<RequestRewriteRule> rules;

  @override
  initState() {
    super.initState();
    rules = widget.requestRewrites.rules;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.only(top: 10),
        constraints: const BoxConstraints(maxHeight: 500, minHeight: 300),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            color: Colors.white,
            backgroundBlendMode: BlendMode.colorBurn),
        child: SingleChildScrollView(
            child: Column(children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(width: 130, padding: const EdgeInsets.only(left: 10), child: const Text("名称")),
              const SizedBox(width: 50, child: Text("启用", textAlign: TextAlign.center)),
              const VerticalDivider(),
              const Expanded(child: Text("URL")),
              const SizedBox(width: 100, child: Text("行为", textAlign: TextAlign.center)),
            ],
          ),
          const Divider(thickness: 0.5),
          Column(children: rows(widget.requestRewrites.rules))
        ])));
  }

  List<Widget> rows(List<RequestRewriteRule> list) {
    var primaryColor = Theme.of(context).primaryColor;

    return List.generate(list.length, (index) {
      return InkWell(
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          hoverColor: primaryColor.withOpacity(0.3),
          onDoubleTap: () async {
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return RuleAddDialog(currentIndex: index, rule: widget.requestRewrites.rules[index]);
                }).then((value) {
              if (value != null) {
                setState(() {});
              }
            });
          },
          onSecondaryTapDown: (details) => showMenus(details, index),
          child: Container(
              color: selected == index
                  ? primaryColor.withOpacity(0.8)
                  : index.isEven
                      ? Colors.grey.withOpacity(0.1)
                      : null,
              height: 30,
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  SizedBox(width: 130, child: Text(list[index].name!, style: const TextStyle(fontSize: 13))),
                  SizedBox(
                      width: 40,
                      child: SwitchWidget(
                          scale: 0.65,
                          value: list[index].enabled,
                          onChanged: (val) {
                            list[index].enabled = val;
                            MultiWindow.invokeRefreshRewrite(Operation.update, index: index, rule: list[index]);
                          })),
                  const SizedBox(width: 20),
                  Expanded(
                      child:
                          Text(list[index].url, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  SizedBox(
                      width: 100,
                      child: Text(list[index].type.label,
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 13))),
                ],
              )));
    });
  }

  //点击菜单
  showMenus(TapDownDetails details, int index) {
    setState(() {
      selected = index;
    });
    showContextMenu(context, details.globalPosition, items: [
      PopupMenuItem(
          height: 35,
          child: const Text("编辑"),
          onTap: () async {
            showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return RuleAddDialog(currentIndex: index, rule: widget.requestRewrites.rules[index]);
                }).then((value) {
              if (value != null) {
                setState(() {});
              }
            });
          }),
      // PopupMenuItem(height: 35, child: const Text("导出"), onTap: () => export(widget.scripts[index])),
      PopupMenuItem(
          height: 35,
          child: rules[index].enabled ? const Text("禁用") : const Text("启用"),
          onTap: () {
            rules[index].enabled = !rules[index].enabled;
            MultiWindow.invokeRefreshRewrite(Operation.update, index: index, rule: rules[index]);
          }),
      const PopupMenuDivider(),
      PopupMenuItem(
          height: 35,
          child: const Text("删除"),
          onTap: () async {
            widget.requestRewrites.removeIndex([index]);
            MultiWindow.invokeRefreshRewrite(Operation.delete, index: index);
            if (context.mounted) FlutterToastr.show('删除成功', context);
          }),
    ]).then((value) {
      setState(() {
        selected = -1;
      });
    });
  }
}
