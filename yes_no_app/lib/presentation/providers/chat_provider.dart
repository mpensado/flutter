import 'package:flutter/material.dart';
import 'package:yes_no_app/config/herlpers/get_answer.dart';
import 'package:yes_no_app/domain/entities/message.dart';

class ChatProvider extends ChangeNotifier {
  final ScrollController chatScrollController = ScrollController();
  final GetAnswer getAnswer = GetAnswer();

  List<Message> messages = [
    Message(text: 'Hola', fromWho: FromWho.me),
    Message(text: 'Estas', fromWho: FromWho.me),
  ];

  Future<void> sendMessage(String message) async {
    if (message.isEmpty) return;

    final newMessage = Message(text: message, fromWho: FromWho.me);
    messages.add(newMessage);
    notifyListeners();
    moveScrollToBottom();

    if (message.endsWith('?')) getReply();
  }

  Future<void> getReply() async {
    final message = await getAnswer.getAnswer();
    messages.add(message);
    notifyListeners();
    moveScrollToBottom();
  }

  Future<void> moveScrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    chatScrollController.animateTo(
        chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut);
  }
}
