import 'package:flutter/material.dart';
import 'package:yes_no_app/widgets/chat/other_message_bubble.dart';
import 'package:yes_no_app/widgets/chat/shared/message_field_box.dart';
import 'package:yes_no_app/widgets/my_message_bubble.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(4.0),
          child: CircleAvatar(
            backgroundImage: NetworkImage(
                'https://static.fundacion-affinity.org/cdn/farfuture/BYYCXdJu1GP-VdTiVMy2i_Q2mAGosc_W8a4Cx4Au1lE/mtime:1653295230/sites/default/files/fundacion-affinity-border-collie.jpg'),
          ),
        ),
        title: const Text("Kyra"),
        centerTitle: false,
      ),
      body: _ChatView(),
    );
  }
}

class _ChatView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Expanded(
                child: ListView.builder(
                  itemCount: 100,
                  itemBuilder: (context, index) {
                    return (index % 2 == 0)
                        ? const OtherMessageBubble()
                        : const MyMessageBubble();
                  },
              )
            ),
            const MessageFieldBox()
          ],
        ),
      ),
    );
  }
}
