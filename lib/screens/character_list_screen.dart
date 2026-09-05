import 'package:flutter/material.dart';
import '../models/character_profile.dart';
import '../services/storage_service.dart';
import '../widgets/character_avatar.dart';
import '../widgets/empty_state_view.dart';
import 'character_edit_screen.dart';
import 'chat_simulation_screen.dart';

class CharacterListScreen extends StatefulWidget {
  const CharacterListScreen({super.key});

  @override
  State<CharacterListScreen> createState() => _CharacterListScreenState();
}

class _CharacterListScreenState extends State<CharacterListScreen> {
  List<CharacterProfile> _characters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    final list = await StorageService.instance.getCharacters();
    if (mounted) {
      setState(() {
        _characters = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.push<CharacterProfile>(
      context,
      MaterialPageRoute(builder: (_) => const CharacterEditScreen()),
    );
    if (result != null) {
      _loadCharacters();
    }
  }

  Future<void> _navigateToEdit(CharacterProfile character) async {
    final result = await Navigator.push<CharacterProfile>(
      context,
      MaterialPageRoute(builder: (_) => CharacterEditScreen(character: character)),
    );
    if (result != null) {
      _loadCharacters();
    }
  }

  void _navigateToChat(CharacterProfile character) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatSimulationScreen(
          character: character,
          initialMessage: character.defaultMorningMessage ?? '안녕! 오늘 하루도 파이팅이야!',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(CharacterProfile character) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('캐릭터 삭제'),
        content: Text('\'${character.name}\' 캐릭터를 삭제하시겠습니까?\n해당 캐릭터로 설정된 알람도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.instance.deleteCharacter(character.id);
      _loadCharacters();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_characters.isEmpty) {
      return EmptyStateView(
        icon: Icons.person_add_alt_1_rounded,
        title: '등록된 캐릭터가 없습니다',
        description: '좋아하는 최애, 연예인, 가상 인물을 직접 등록하여\n모닝콜 발신자로 지정해 보세요.',
        buttonText: '첫 캐릭터 등록하기',
        onButtonPressed: _navigateToAdd,
      );
    }

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _characters.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final character = _characters[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CharacterAvatar(
                name: character.name,
                avatarPath: character.avatarPath,
                radius: 26,
              ),
              title: Text(
                character.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: character.title != null
                  ? Text(
                      character.title!,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.chat_bubble_outline_rounded, color: Theme.of(context).colorScheme.primary),
                    tooltip: 'AI 대화하기',
                    onPressed: () => _navigateToChat(character),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                    onPressed: () => _confirmDelete(character),
                  ),
                ],
              ),
              onTap: () => _navigateToEdit(character),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        icon: const Icon(Icons.add),
        label: const Text('캐릭터 추가'),
      ),
    );
  }
}
