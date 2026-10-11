import 'dart:async';

import 'package:flutter/material.dart';
import '../app.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';
import '../services/websocket_service.dart';

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.fromMe,
    required this.time,
  });

  final String text;
  final bool fromMe;
  final String time;
}

/// Rider chat UI for messaging the customer while a delivery is live.
///
/// Runs against the realtime backend: history is loaded from
/// /api/v1/chat/:deliveryId, sends go over the same endpoint, and inbound
/// messages arrive live as `chat.message` WebSocket events on the shared
/// [ws] connection.
class RiderChatScreen extends StatefulWidget {
  const RiderChatScreen({
    super.key,
    required this.deliveryId,
    this.contactName = 'Customer',
    this.contactSubtitle = 'MarketGO Customer',
    this.bannerTitle,
    this.bannerSubtitle,
    this.token,
    this.currentUserId,
    this.ws,
    this.api,
  });

  final int deliveryId;
  final String contactName;
  final String contactSubtitle;

  /// Optional context banner (e.g. "Pickup → Drop-off").
  final String? bannerTitle;
  final String? bannerSubtitle;

  final String? token;
  final int? currentUserId;

  /// Shared WebSocket connection to receive inbound messages in real time.
  final RiderWebSocket? ws;
  final ApiClient? api;

  @override
  State<RiderChatScreen> createState() => _RiderChatScreenState();
}

class _RiderChatScreenState extends State<RiderChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  RiderChatService? _service;
  StreamSubscription<RiderWsEvent>? _chatSub;

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    var h = local.hour % 12;
    if (h == 0) h = 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ap = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  @override
  void initState() {
    super.initState();
    _service = RiderChatService(api: widget.api);
    _watchInbound();
    _loadHistory();
  }

  void _watchInbound() {
    final ws = widget.ws;
    if (ws == null) return;
    _chatSub = ws.chatMessage.listen((event) {
      if (!mounted) return;
      final payload = event.payload;
      if (payload is! Map<String, dynamic>) return;
      final deliveryId = (payload['delivery_id'] as num?)?.toInt();
      if (deliveryId == null || deliveryId != widget.deliveryId) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: payload['body'] as String? ?? '',
          fromMe: false,
          time: _formatTime(
            DateTime.tryParse(payload['created_at'] as String? ?? '') ??
                DateTime.now(),
          ),
        ));
      });
      _scrollToBottom();
    });
  }

  Future<void> _loadHistory() async {
    final token = widget.token;
    if (token == null) return;
    try {
      final (_, history) = await _service!.conversation(token, widget.deliveryId);
      if (!mounted) return;
      setState(() {
        for (final m in history) {
          _messages.add(_ChatMessage(
            text: m.body,
            fromMe: m.senderId == widget.currentUserId,
            time: _formatTime(m.createdAt),
          ));
        }
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 409) return;
      _toast('Couldn\'t load messages: ${e.message}');
    } catch (_) {
      _toast('Couldn\'t load messages.');
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() {
      _messages.add(_ChatMessage(text: text, fromMe: true, time: _formatTime(DateTime.now())));
    });
    _scrollToBottom();

    final token = widget.token;
    if (token == null) return;
    try {
      await _service!.send(token, widget.deliveryId, text);
    } on ApiException catch (e) {
      // Restore the draft on failure so the rider doesn't lose it.
      _input.text = text;
      _toast('Message failed: ${e.message}');
    } catch (_) {
      _input.text = text;
      _toast('Message failed. Try again.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderApp.surfaceMuted,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        automaticallyImplyLeading: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.contactName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: RiderApp.ink,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Color(0xFF22C55E)),
                const SizedBox(width: 5),
                Text(
                  widget.contactSubtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5B616A)),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (widget.bannerTitle != null) _DeliveryBanner(
            title: widget.bannerTitle!,
            subtitle: widget.bannerSubtitle ?? '',
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _Bubble(message: _messages[index]),
            ),
          ),
          _Composer(
            controller: _input,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

/// Compact banner contextualising the conversation with the active trip.
class _DeliveryBanner extends StatelessWidget {
  const _DeliveryBanner({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: RiderApp.brandGreenLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.delivery_dining_rounded,
              color: RiderApp.brandGreenDark, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: RiderApp.brandGreenDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: RiderApp.brandGreenDark,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: message.fromMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.74,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        decoration: BoxDecoration(
          color: message.fromMe ? RiderApp.brandGreen : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(message.fromMe ? 18 : 4),
            bottomRight: Radius.circular(message.fromMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.fromMe ? Colors.white : RiderApp.ink,
                fontSize: 14.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message.time,
              style: TextStyle(
                color: message.fromMe
                    ? Colors.white70
                    : theme.textTheme.bodySmall?.color,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.only(left: 16, right: 12, top: 10, bottom: 10),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: RiderApp.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: onSend,
                style: IconButton.styleFrom(
                  backgroundColor: RiderApp.brandGreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_rounded, size: 20),
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ),
    );
  }
}