import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rive/rive.dart';

import '../../../data/models/character_model.dart';
import '../../../data/models/enums.dart';
import '../domain/age_appearance.dart';
import '../providers/character_animation_provider.dart';
import 'fallback_character_animator.dart';

/// Loads stage-specific Rive artboard when present; otherwise animated fallback.
///
/// Never fully static — Rive state machine or fallback breathe/blink/sway.
class RiveCharacterView extends ConsumerStatefulWidget {
  const RiveCharacterView({
    super.key,
    required this.character,
    this.size = 320,
    this.onTap,
    this.onStroke,
    this.onPoke,
    this.onShake,
  });

  final CharacterModel character;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onStroke;
  final VoidCallback? onPoke;
  final VoidCallback? onShake;

  @override
  ConsumerState<RiveCharacterView> createState() => _RiveCharacterViewState();
}

class _RiveCharacterViewState extends ConsumerState<RiveCharacterView> {
  Artboard? _artboard;
  StateMachineController? _machine;
  SMITrigger? _tap;
  SMITrigger? _stroke;
  SMITrigger? _poke;
  SMITrigger? _shake;
  SMIBool? _talking;
  SMIBool? _sleeping;
  SMINumber? _mood;
  bool _loading = true;
  bool _hasRive = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RiveCharacterView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.character.stage != widget.character.stage ||
        oldWidget.character.type != widget.character.type) {
      _load();
    } else {
      _pushInputs();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasRive = false;
      _artboard = null;
      _machine?.dispose();
      _machine = null;
    });

    final appearance = AgeAppearance.forAge(widget.character.age);
    final path = appearance.riveAsset(widget.character.type);

    try {
      await rootBundle.load(path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasRive = false;
        });
      }
      return;
    }

    try {
      final file = await RiveFile.asset(path);
      final artboard = file.mainArtboard;
      final machine =
          StateMachineController.fromArtboard(artboard, 'Character');
      if (machine != null) {
        artboard.addController(machine);
        _tap = machine.findInput<SMITrigger>('tap') as SMITrigger?;
        _stroke = machine.findInput<SMITrigger>('stroke') as SMITrigger?;
        _poke = machine.findInput<SMITrigger>('poke') as SMITrigger?;
        _shake = machine.findInput<SMITrigger>('shake') as SMITrigger?;
        _talking = machine.findInput<bool>('talking') as SMIBool?;
        _sleeping = machine.findInput<bool>('sleeping') as SMIBool?;
        _mood = machine.findInput<double>('mood') as SMINumber?;
        _machine = machine;
      } else {
        // Still show artboard with default animation if any.
        artboard.addController(SimpleAnimation('idle'));
      }
      if (!mounted) return;
      setState(() {
        _artboard = artboard;
        _hasRive = true;
        _loading = false;
      });
      _pushInputs();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasRive = false;
        });
      }
    }
  }

  void _pushInputs() {
    if (!mounted) return;
    final anim = ref.read(characterAnimationProvider);
    _talking?.value = anim.talking;
    _sleeping?.value = widget.character.isSleeping;
    _mood?.value = widget.character.mood;
  }

  void _fire(InteractionGesture g) {
    switch (g) {
      case InteractionGesture.tap:
        _tap?.fire();
      case InteractionGesture.stroke:
        _stroke?.fire();
      case InteractionGesture.pokeForehead:
        _poke?.fire();
      case InteractionGesture.shake:
        _shake?.fire();
    }
    ref.read(characterAnimationProvider.notifier).react(g);
  }

  @override
  void dispose() {
    _machine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(characterAnimationProvider, (_, _) => _pushInputs());

    final appearance = AgeAppearance.forAge(widget.character.age);
    final size = widget.size * appearance.scale;

    Widget child;
    if (_loading) {
      child = SizedBox(
        width: size,
        height: size,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_hasRive && _artboard != null) {
      child = SizedBox(
        width: size,
        height: size * 1.05,
        child: Rive(
          artboard: _artboard!,
          fit: BoxFit.contain,
        ),
      );
    } else {
      final anim = ref.watch(characterAnimationProvider);
      child = FallbackCharacterAnimator(
        character: widget.character,
        size: size,
        pose: anim.effectivePose,
        talking: anim.talking,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        widget.onTap?.call();
        _fire(InteractionGesture.tap);
      },
      onLongPress: () {
        widget.onStroke?.call();
        _fire(InteractionGesture.stroke);
      },
      onDoubleTap: () {
        widget.onPoke?.call();
        _fire(InteractionGesture.pokeForehead);
      },
      onPanEnd: (_) {
        widget.onShake?.call();
        _fire(InteractionGesture.shake);
      },
      child: child,
    );
  }
}
