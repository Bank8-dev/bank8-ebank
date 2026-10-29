// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Bank8:EBank
// SPDX-License-Identifier: Apache-2.0

// eBank - Messages page (Post inbox viewer).
//
// Shows a list of messages from Post (notifications, emails, SMS, CIBA
// approval requests, etc.) for the current user. Clicking a message opens
// the detail view with the full body. URLs in the body are rendered as
// tappable links that open in a new browser tab.
//
// Pull: GET /proxy/post/v1/messages?mine=true (filtered by recipient_user_id)
// Push: BFF SSE notification.received increments the unread badge
//
// Design: design/sentin8-post-technical-design.md §13 Epic 18.6

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:js_interop';
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;
import '../app_context.dart';
import '../theme.dart';
import '../notification_sse.dart';
import '../url_router.dart';

class MessagesPage extends StatefulWidget {
  final EBankContext appContext;
  final NotificationSseClient? sseClient;

  const MessagesPage({super.key, required this.appContext, this.sseClient});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<dynamic>? _messages;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _selectedMessage;
  bool _loadingDetail = false;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _openMessage(Map<String, dynamic> msg) async {
    final id = msg['id'] as String?;
    final isRead = msg['read'] as bool? ?? false;
    setState(() { _selectedMessage = msg; _loadingDetail = true; });
    if (id != null) pushRoute('/messages/$id');
    // Mark the message as read on the server (fire-and-forget - don't await).
    // The SSE notification.read event will push the authoritative unread_count.
    // Decrement locally immediately for instant UI feedback.
    if (id != null && !isRead) {
      widget.sseClient?.decrementUnread();
      final services = widget.appContext.services;
      if (services != null) {
        services.post.post('/v1/messages/$id/read').catchError((_) {});
      }
    }
    // Fetch full message detail (includes body + metadata).
    if (id != null) {
      try {
        final services = widget.appContext.services;
        if (services != null) {
          final resp = await services.post.get('/v1/messages/$id');
          if (resp.isSuccess && resp.data != null) {
            // Post returns a bare JSON object; the ApiClient wraps it
            // as a Map with the object's fields directly.
            setState(() { _selectedMessage = resp.data; });
          }
        }
      } catch (_) {}
    }
    setState(() { _loadingDetail = false; });
  }

  Future<void> _fetchMessages() async {
    setState(() { _loading = true; _error = null; });
    try {
      final services = widget.appContext.services;
      if (services == null) {
        setState(() { _error = 'Services not initialized'; _loading = false; });
        return;
      }
      final resp = await services.post.get('/v1/messages', queryParams: {'mine': 'true', 'limit': '100'});
      if (!resp.isSuccess) {
        throw Exception('Failed to load messages (${resp.statusCode}): ${resp.error ?? resp.data}');
      }
      // Post returns a bare JSON array; the ApiClient wraps it as {'data': [...]}.
      _messages = resp.data?['data'] as List<dynamic>? ?? [];
    } catch (e) {
      _messages = [];
      _error = e.toString();
    }
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedMessage != null) {
      return _MessageDetailView(
        message: _selectedMessage!,
        onBack: () {
          setState(() { _selectedMessage = null; });
          navigateTo('/messages');
          _fetchMessages();
        },
      );
    }
    // No Scaffold - the eBank shell wraps content in SingleChildScrollView.
    // Using a Column with a header row + content avoids the nested
    // Scaffold-in-scroll-view height collapse.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.all(Sentin8Spacing.lg),
          child: Row(
            children: [
              Text('Messages', style: Sentin8Text.headlineMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _fetchMessages,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        // Content
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: Sentin8Spacing.xxl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: Sentin8Spacing.xxl),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Sentin8Colors.error),
                  const SizedBox(height: Sentin8Spacing.md),
                  Text(_error!, style: Sentin8Text.bodyMedium, textAlign: TextAlign.center),
                  const SizedBox(height: Sentin8Spacing.md),
                  FilledButton(onPressed: _fetchMessages, child: const Text('Retry')),
                ],
              ),
            ),
          )
        else if (_messages == null || _messages!.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Sentin8Spacing.xxl),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 64, color: Sentin8Colors.textSecondary.withValues(alpha: 0.5)),
                  const SizedBox(height: Sentin8Spacing.md),
                  Text('No messages', style: Sentin8Text.headlineMedium),
                  const SizedBox(height: Sentin8Spacing.sm),
                  Text('You have no messages at this time.', style: Sentin8Text.bodyMedium),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(Sentin8Spacing.lg),
            itemCount: _messages!.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final msg = _messages![index] as Map<String, dynamic>;
              return _MessageTile(
                message: msg,
                onTap: () => _openMessage(msg),
              );
            },
          ),
      ],
    );
  }
}

class _MessageTile extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onTap;

  const _MessageTile({required this.message, required this.onTap});

  IconData _categoryIcon(String? category) {
    switch (category) {
      case 'security':
        return Icons.security;
      case 'transaction':
        return Icons.receipt_long;
      case 'payment':
        return Icons.payment;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = message['subject'] as String? ?? '(no subject)';
    final category = message['category'] as String? ?? 'system';
    final messageType = message['message_type'] as String? ?? '';
    final createdAt = message['created_at'] as String? ?? '';
    final isRead = message['read'] as bool? ?? false;

    // Format timestamp.
    String timeStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        timeStr = '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {
        timeStr = createdAt.substring(0, createdAt.length > 16 ? 16 : createdAt.length);
      }
    }

    return ListTile(
      leading: Icon(_categoryIcon(category), color: isRead ? Sentin8Colors.textSecondary : Sentin8Colors.primary),
      title: Text(
        subject,
        style: Sentin8Text.bodyMedium.copyWith(
          fontWeight: isRead ? FontWeight.w400 : FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '$messageType · $timeStr',
        style: Sentin8Text.labelSmall.copyWith(color: Sentin8Colors.textSecondary),
      ),
      trailing: isRead
          ? const Icon(Icons.check_circle_outline, size: 16, color: Sentin8Colors.textSecondary)
          : Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(color: Sentin8Colors.primary, shape: BoxShape.circle),
            ),
      onTap: onTap,
    );
  }
}

class _MessageDetailView extends StatelessWidget {
  final Map<String, dynamic> message;
  final VoidCallback onBack;

  const _MessageDetailView({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final subject = message['subject'] as String? ?? '(no subject)';
    final body = message['body'] as String? ?? '';
    final messageType = message['message_type'] as String? ?? '';
    final category = message['category'] as String? ?? 'system';
    final priority = message['priority'] as String? ?? 'normal';
    final createdAt = message['created_at'] as String? ?? '';
    final metadata = message['metadata'] as Map<String, dynamic>?;

    // Format timestamp.
    String timeStr = createdAt;
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt);
        timeStr = dt.toLocal().toString().substring(0, 19);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        title: const Text('Message'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Sentin8Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subject, style: Sentin8Text.headlineMedium),
            const SizedBox(height: Sentin8Spacing.sm),
            Wrap(
              spacing: 8,
              children: [
                _Chip(label: messageType),
                _Chip(label: category),
                if (priority != 'normal') _Chip(label: priority, color: Sentin8Colors.error),
              ],
            ),
            const SizedBox(height: Sentin8Spacing.sm),
            Text(timeStr, style: Sentin8Text.labelSmall.copyWith(color: Sentin8Colors.textSecondary)),
            const SizedBox(height: Sentin8Spacing.lg),
            const Divider(),
            const SizedBox(height: Sentin8Spacing.lg),
            _MessageBody(body: body),
            if (metadata != null && metadata.isNotEmpty) ...[
              const SizedBox(height: Sentin8Spacing.xl),
              const Divider(),
              const SizedBox(height: Sentin8Spacing.md),
              Text('Metadata', style: Sentin8Text.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: Sentin8Spacing.sm),
              Container(
                padding: const EdgeInsets.all(Sentin8Spacing.md),
                decoration: BoxDecoration(
                  color: Sentin8Colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Sentin8Colors.border),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(metadata),
                  style: Sentin8Text.labelSmall.copyWith(fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders the message body, detecting URLs and turning them into tappable
/// links that open in a new browser tab.
class _MessageBody extends StatelessWidget {
  final String body;

  const _MessageBody({required this.body});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final urlRegex = RegExp(r'''https?://[^\s<>"']+''');
    int lastEnd = 0;
    for (final match in urlRegex.allMatches(body)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: body.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(color: Sentin8Colors.primary, decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            final url = match.group(0)!;
            // Open in a new browser tab (web only).
            web.window.open(url, '_blank');
          },
      ));
      lastEnd = match.end;
    }
    if (lastEnd < body.length) {
      spans.add(TextSpan(text: body.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(
        style: Sentin8Text.bodyMedium.copyWith(height: 1.5),
        children: spans.isEmpty ? [TextSpan(text: body)] : spans,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;

  const _Chip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Sentin8Colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: Sentin8Text.labelSmall.copyWith(color: c, fontSize: 11)),
    );
  }
}