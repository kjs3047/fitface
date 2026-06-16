import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/profile/body_type.dart';
import '../../../providers/user_profile_provider.dart';
import '../../widgets/app_top_bar.dart';

/// 설정 > 사용자 기본정보.
/// 키·몸무게·체형을 미리 1회 등록해 두고, 가상착장이 이 값을 가져다 쓴다.
class UserBasicInfoScreen extends ConsumerStatefulWidget {
  const UserBasicInfoScreen({super.key});

  @override
  ConsumerState<UserBasicInfoScreen> createState() =>
      _UserBasicInfoScreenState();
}

class _UserBasicInfoScreenState extends ConsumerState<UserBasicInfoScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  Gender _gender = defaultGender;
  BodyType _bodyType = defaultBodyType;
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _prefill() {
    if (_prefilled) {
      return;
    }
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile != null) {
      _gender = profile.gender ?? defaultGender;
      _bodyType = profile.bodyType ?? defaultBodyType;
      if (profile.heightCm != null) {
        _heightController.text = profile.heightCm.toString();
      }
      if (profile.weightKg != null) {
        _weightController.text = profile.weightKg.toString();
      }
    }
    _prefilled = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(userProfileProvider.notifier).saveBasicInfo(
            gender: _gender,
            bodyType: _bodyType,
            heightCm: int.tryParse(_heightController.text.trim()),
            weightKg: int.tryParse(_weightController.text.trim()),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기본정보를 저장했어요.')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장에 실패했어요: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 프로필 로드가 끝나면 1회 prefill.
    ref.listen(userProfileProvider, (_, __) => setState(_prefill));
    _prefill();

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: const AppTopBar(title: '사용자 기본정보'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              '가상착장에 사용하는 정보예요. 한 번만 등록하면 됩니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            const _SectionLabel('성별'),
            const SizedBox(height: 8),
            _GenderToggle(
              value: _gender,
              onChanged: (g) => setState(() => _gender = g),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('키 / 몸무게 (선택)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    controller: _heightController,
                    label: '키',
                    suffix: 'cm',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumberField(
                    controller: _weightController,
                    label: '몸무게',
                    suffix: 'kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _SectionLabel('체형'),
            const SizedBox(height: 8),
            _BodyTypeGrid(
              gender: _gender,
              selected: _bodyType,
              onChanged: (t) => setState(() => _bodyType = t),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _GenderToggle extends StatelessWidget {
  const _GenderToggle({required this.value, required this.onChanged});

  final Gender value;
  final ValueChanged<Gender> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final g in Gender.values) ...[
          Expanded(
            child: _SelectableChip(
              label: g.label,
              selected: g == value,
              onTap: () => onChanged(g),
            ),
          ),
          if (g != Gender.values.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.ink : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.ink : AppTheme.line,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: selected ? AppTheme.surface : AppTheme.ink,
              ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _BodyTypeGrid extends StatelessWidget {
  const _BodyTypeGrid({
    required this.gender,
    required this.selected,
    required this.onChanged,
  });

  final Gender gender;
  final BodyType selected;
  final ValueChanged<BodyType> onChanged;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      // 이미지 2:3 + 하단 라벨 + 패딩을 담도록 카드를 세로로 길게.
      childAspectRatio: 0.58,
      children: [
        for (final type in BodyType.values)
          _BodyTypeCard(
            key: Key('body-type-${type.name}'),
            gender: gender,
            type: type,
            selected: type == selected,
            onTap: () => onChanged(type),
          ),
      ],
    );
  }
}

class _BodyTypeCard extends StatelessWidget {
  const _BodyTypeCard({
    required this.gender,
    required this.type,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Gender gender;
  final BodyType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentSoft : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.ink : AppTheme.line,
            width: selected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 원본 PNG가 2:3(1024x1536)으로 통일돼 있어 같은 비율 틀에
            // contain으로 넣으면 잘림·여백 없이 가지런하다.
            AspectRatio(
              aspectRatio: 2 / 3,
              child: _BodyTypeImage(gender: gender, type: type),
            ),
            const SizedBox(height: 6),
            Text(
              type.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 체형 실루엣 이미지. 애셋이 없으면(아직 미제공) 아이콘으로 폴백한다.
class _BodyTypeImage extends StatelessWidget {
  const _BodyTypeImage({required this.gender, required this.type});

  final Gender gender;
  final BodyType type;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        bodyTypeAsset(gender, type),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(
            Icons.accessibility_new,
            color: AppTheme.mutedInk,
            size: 36,
          ),
        ),
      ),
    );
  }
}
