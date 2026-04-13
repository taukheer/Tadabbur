import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:tadabbur/core/constants/translations.dart';
import 'package:tadabbur/core/models/ayah.dart';
import 'package:tadabbur/core/models/editorial_content.dart';
import 'package:tadabbur/core/models/journal_entry.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/theme/app_colors.dart';
import 'package:tadabbur/features/daily_ayah/providers/daily_ayah_provider.dart';

class ReflectionScreen extends ConsumerStatefulWidget {
  final Ayah ayah;
  final EditorialContent? editorial;

  const ReflectionScreen({
    super.key,
    required this.ayah,
    this.editorial,
  });

  @override
  ConsumerState<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends ConsumerState<ReflectionScreen> {
  static const _maxReflectionLength = 2000;

  final _textController = TextEditingController();
  bool _isSaving = false;
  bool _isComplete = false;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _t(String key) =>
      AppTranslations.get(key, ref.watch(languageProvider));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isComplete) return _buildCompletion(theme);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Close button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),

            // The ayah — small reminder at top
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(36, 8, 36, 0),
                child: Text(
                  widget.ayah.textUthmani,
                  locale: const Locale('ar'),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'AmiriQuran',
                    fontSize: 22,
                    color: AppColors.textPrimaryLight,
                    height: 2.0,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ).animate().fadeIn(duration: 600.ms),
              ),
            ),

            // Translation
            if (widget.ayah.translationText != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 12, 40, 0),
                  child: Text(
                    widget.ayah.translationText!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                ),
              ),

            // Divider
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(80, 28, 80, 28),
                child: Divider(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  thickness: 0.5,
                ),
              ),
            ),

            // The question — the heart of the reflection
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                child: Text(
                  widget.editorial?.tier3Question ??
                      _t('what_ayah_say'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                    fontSize: 17,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 800.ms, delay: 400.ms)
                    .slideY(begin: 0.03, end: 0, duration: 800.ms, delay: 400.ms),
              ),
            ),

            // Writing space
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  maxLines: null,
                  minLines: 6,
                  maxLength: _maxReflectionLength,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_maxReflectionLength),
                  ],
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.8,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                  decoration: InputDecoration(
                    hintText: _t('write_freely'),
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    ),
                    filled: true,
                    fillColor: AppColors.primary.withValues(alpha: 0.02),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.06),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.06),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
              ),
            ),

            // Action buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  children: [
                    // Save reflection (if they wrote something)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _isSaving ? null : () => _save(withText: true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _t('save_reflection'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // "This spoke to me" — the gentle alternative
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: _isSaving ? null : () => _save(withText: false),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Text(
                          _t('this_spoke'),
                          style: TextStyle(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 500.ms, delay: 800.ms),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Future<void> _save({required bool withText}) async {
    final text = _textController.text.trim();

    // If they clicked "Save Reflection" but wrote nothing, nudge gently
    if (withText && text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Write a reflection, or tap "This spoke to me" below'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Determine tier naturally from what they did
      ReflectionTier tier;
      String? responseText;
      String? promptText;

      if (!withText) {
        tier = ReflectionTier.acknowledge;
      } else if (text.length < 80) {
        tier = ReflectionTier.respond;
        responseText = text;
        promptText = widget.editorial?.tier2Prompt;
      } else {
        tier = ReflectionTier.reflect;
        responseText = text;
        promptText = widget.editorial?.tier3Question;
      }

      final entry = JournalEntry(
        id: const Uuid().v4(),
        verseKey: widget.ayah.verseKey,
        arabicText: widget.ayah.textUthmani,
        translationText: widget.ayah.translationText ?? '',
        tier: tier,
        promptText: promptText,
        responseText: responseText,
        completedAt: DateTime.now(),
        streakDay: ref.read(userProgressProvider).totalAyatCompleted + 1,
      );

      await ref.read(journalProvider.notifier).addEntry(entry);
      await ref
          .read(userProgressProvider.notifier)
          .completeAyah(widget.ayah.verseKey);
      ref.read(dailyAyahProvider.notifier).markCompleted();

      setState(() {
        _isSaving = false;
        _isComplete = true;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  Widget _buildCompletion(ThemeData theme) {
    final progress = ref.watch(userProgressProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                Icon(
                  Icons.check_rounded,
                  color: AppColors.primary.withValues(alpha: 0.3),
                  size: 48,
                )
                    .animate()
                    .fadeIn(duration: 800.ms)
                    .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      duration: 800.ms,
                      curve: Curves.easeOut,
                    ),

                const SizedBox(height: 32),

                Text(
                  _t('sat_with_ayat').replaceAll('{n}', '${progress.totalAyatCompleted}'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
                ).animate().fadeIn(duration: 800.ms, delay: 400.ms),

                const SizedBox(height: 8),

                Text(
                  _t('next_ready'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ).animate().fadeIn(duration: 800.ms, delay: 600.ms),

                const Spacer(flex: 2),

                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    _t('return_btn'),
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
