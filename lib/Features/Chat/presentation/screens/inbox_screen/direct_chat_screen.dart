import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/Features/Me/presentation/providers/chat_theme_provider.dart';
import '../../providers/direct_chat_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/in_chat_search_provider.dart';
import '../../widgets/chatAppbar.dart';
import '../../widgets/connection_status_banner.dart';
import 'widgets/inbox_providers.dart';
import 'widgets/composer_bar.dart';
import 'widgets/attachment_drawer.dart';
import 'widgets/direct_message_list.dart';
import 'widgets/message_preview_bars.dart';

// Re-export providers and widgets so external imports remain unbroken
export 'widgets/inbox_providers.dart';
export 'widgets/pinned_message_bar.dart';
export 'widgets/date_chip.dart';
export 'widgets/typing_indicator_widget.dart';
export 'widgets/message_preview_bars.dart';
export 'widgets/composer_bar.dart';
export 'widgets/attachment_drawer.dart';
export 'widgets/direct_message_list.dart';

class DirectChatScreen extends ConsumerStatefulWidget {
  const DirectChatScreen({super.key});

  @override
  ConsumerState<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends ConsumerState<DirectChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  Timer? _draftDebounce;
  DirectChatNotifier? _directChatNotifier;
  bool _isEditing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _directChatNotifier = ref.read(directChatProvider.notifier);
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _messageController.addListener(_onTextChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatReadyProvider.notifier).state = true;
        final chatId = ref.read(currentChatIdProvider);
        if (chatId != null) {
          ref.read(chatProvider.notifier).clearUnreadCount(chatId);
          // Restore draft message if present
          ref.read(directChatProvider.notifier).getDraft().then((savedDraft) {
            if (mounted &&
                savedDraft != null &&
                savedDraft.isNotEmpty &&
                _messageController.text.isEmpty) {
              _messageController.text = savedDraft;
              _messageController.selection = TextSelection.collapsed(
                offset: savedDraft.length,
              );
            }
          });
        }
      }
    });
  }

  void _onTextChanged() {
    final editingMsg = ref.read(editingMessageProvider);
    if (editingMsg != null) return;
    _draftDebounce?.cancel();
    _draftDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref
            .read(directChatProvider.notifier)
            .saveDraft(_messageController.text);
      }
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      ref.read(showAttachmentMenuProvider.notifier).state = false;
    }
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    if (!_isEditing) {
      _directChatNotifier?.saveDraft(_messageController.text);
    }
    _messageController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChange);
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(directChatProvider.notifier).saveDraft(null);

    final editingMsg = ref.read(editingMessageProvider);
    if (editingMsg != null) {
      ref.read(directChatProvider.notifier).editMessage(editingMsg.id, text);
      ref.read(editingMessageProvider.notifier).state = null;
    } else {
      final replyTo = ref.read(replyingToProvider);
      ref
          .read(directChatProvider.notifier)
          .sendMessage(text, replyToId: replyTo?.id);
      ref.read(replyingToProvider.notifier).state = null;
    }

    _messageController.clear();
    _focusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(editingMessageProvider, (previous, next) {
      _isEditing = next != null;
      if (next != null) {
        _messageController.text = next.text;
        _focusNode.requestFocus();
      }
    });

    final activeTheme = ref.watch(chatThemeProvider);
    final headerTextColor = ref.watch(headerTextColorProvider);
    final inChatSearch = ref.watch(inChatSearchProvider);

    return PopScope(
      canPop: !inChatSearch.isActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && inChatSearch.isActive) {
          ref.read(inChatSearchProvider.notifier).deactivate();
          return;
        }
        if (didPop) {
          if (!_isEditing) {
            _directChatNotifier?.saveDraft(_messageController.text);
          }
          ref.read(currentChatIdProvider.notifier).state = null;
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: activeTheme.backgroundColor,
        appBar: ChatAppBar(
          activeTheme: activeTheme,
          headerTextColor: headerTextColor,
        ),
        body: SafeArea(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                const ConnectionStatusBanner(),
                Expanded(
                  child: ReadyGate(scrollController: _scrollController),
                ),
                const EditPreviewBar(),
                const ReplyPreviewBar(),
                ComposerBar(
                  messageController: _messageController,
                  focusNode: _focusNode,
                  activeTheme: activeTheme,
                  onSend: _sendMessage,
                  onAttach: () async {
                    final current = ref.read(showAttachmentMenuProvider);
                    if (current) {
                      ref.read(showAttachmentMenuProvider.notifier).state =
                          false;
                      _focusNode.requestFocus();
                    } else {
                      final wasKeyboardOpen = _focusNode.hasFocus;
                      FocusScope.of(context).unfocus();

                      if (wasKeyboardOpen) {
                        await Future.delayed(const Duration(milliseconds: 260));
                        if (!mounted) return;
                      }

                      ref.read(showAttachmentMenuProvider.notifier).state =
                          true;
                    }
                  },
                ),
                const AttachmentDrawerSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
