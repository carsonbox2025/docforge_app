import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';

final _legalCache = <String, Map<String, String>>{};

class LegalPage extends StatefulWidget {
  final String type;
  const LegalPage({super.key, required this.type});

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  String _content = '';
  String _title = '';
  bool _isLoading = true;
  String? _error;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final cached = _legalCache[widget.type];
    if (cached != null) {
      if (!mounted) return;
      setState(() {
        _title = cached['title'] ?? '';
        _content = cached['content'] ?? '';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    _cancelToken = CancelToken();
    try {
      final response = await ApiClient.instance.get(
        AppConstants.legalUrl(widget.type),
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      if (_cancelToken?.isCancelled == true) return;
      final data = response.data['data'] as Map<String, dynamic>?;
      if (!mounted) return;
      if (data != null) {
        _legalCache[widget.type] = {
          'title': data['title']?.toString() ?? '',
          'content': data['content']?.toString() ?? '',
        };
        setState(() {
          _title = _legalCache[widget.type]!['title']!;
          _content = _legalCache[widget.type]!['content']!;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_cancelToken?.isCancelled == true) return;
      if (!mounted) return;
      setState(() {
        _error = '加载失败，请检查网络';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(_title.isEmpty ? '加载中...' : _title),
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: AppColors.text,
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _content.isEmpty
                  ? const Center(child: Text('暂无内容', style: TextStyle(color: AppColors.textMuted)))
                  : MarkdownBody(
                      data: _content,
                      selectable: true,
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadContent,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
