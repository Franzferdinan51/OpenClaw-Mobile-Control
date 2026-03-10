import 'package:flutter/material.dart';
import '../services/gateway_service.dart';

/// Voice Configuration Screen
/// Voice Wake, Talk Mode, ElevenLabs API, TTS Voice Selection
class VoiceConfigScreen extends StatefulWidget {
  final GatewayService? gatewayService;

  const VoiceConfigScreen({super.key, this.gatewayService});

  @override
  State<VoiceConfigScreen> createState() => _VoiceConfigScreenState();
}

class _VoiceConfigScreenState extends State<VoiceConfigScreen> {
  // Voice Wake Settings
  bool _voiceWakeEnabled = true;
  String _wakeWord = 'Hey DuckBot';
  double _wakeSensitivity = 0.7;
  
  // Talk Mode Settings
  bool _talkModeEnabled = false;
  bool _continuousListening = false;
  double _silenceThreshold = 1.5; // seconds
  
  // TTS Settings
  String _selectedTtsProvider = 'elevenlabs';
  String _selectedVoice = 'Nova';
  double _speechRate = 1.0;
  double _pitch = 1.0;
  
  // API Keys
  String _elevenLabsApiKey = '';
  bool _obscureApiKey = true;
  
  // Available voices
  final List<VoiceOption> _availableVoices = [
    VoiceOption(id: 'nova', name: 'Nova', provider: 'openai', description: 'Warm, slightly British'),
    VoiceOption(id: 'alloy', name: 'Alloy', provider: 'openai', description: 'Neutral, balanced'),
    VoiceOption(id: 'echo', name: 'Echo', provider: 'openai', description: 'Male, conversational'),
    VoiceOption(id: 'fable', name: 'Fable', provider: 'openai', description: 'British, storytelling'),
    VoiceOption(id: 'onyx', name: 'Onyx', provider: 'openai', description: 'Deep male voice'),
    VoiceOption(id: 'shimmer', name: 'Shimmer', provider: 'openai', description: 'Soft, warm female'),
    VoiceOption(id: 'rachel', name: 'Rachel', provider: 'elevenlabs', description: 'Professional female'),
    VoiceOption(id: 'domi', name: 'Domi', provider: 'elevenlabs', description: 'Bold, expressive'),
    VoiceOption(id: 'bella', name: 'Bella', provider: 'elevenlabs', description: 'Soft, melodic'),
    VoiceOption(id: 'antoni', name: 'Antoni', provider: 'elevenlabs', description: 'Deep, smooth male'),
    VoiceOption(id: 'josh', name: 'Josh', provider: 'elevenlabs', description: 'Casual, friendly male'),
    VoiceOption(id: 'arnold', name: 'Arnold', provider: 'elevenlabs', description: 'Dramatic, announcer'),
  ];

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelp,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Voice Wake Section
                _buildSection(
                  title: 'Voice Wake',
                  subtitle: 'Wake word activation settings',
                  icon: Icons.mic,
                  children: [
                    SwitchListTile(
                      title: const Text('Enable Voice Wake'),
                      subtitle: const Text('Activate with wake word'),
                      value: _voiceWakeEnabled,
                      onChanged: (value) => setState(() => _voiceWakeEnabled = value),
                    ),
                    ListTile(
                      title: const Text('Wake Word'),
                      subtitle: Text(_wakeWord),
                      trailing: const Icon(Icons.edit),
                      enabled: _voiceWakeEnabled,
                      onTap: () => _editWakeWord(),
                    ),
                    ListTile(
                      title: const Text('Sensitivity'),
                      subtitle: Text('${(_wakeSensitivity * 100).toInt()}%'),
                      enabled: _voiceWakeEnabled,
                    ),
                    Slider(
                      value: _wakeSensitivity,
                      min: 0.3,
                      max: 1.0,
                      divisions: 7,
                      onChanged: _voiceWakeEnabled ? (value) => setState(() => _wakeSensitivity = value) : null,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Talk Mode Section
                _buildSection(
                  title: 'Talk Mode',
                  subtitle: 'Continuous voice interaction',
                  icon: Icons.record_voice_over,
                  children: [
                    SwitchListTile(
                      title: const Text('Enable Talk Mode'),
                      subtitle: const Text('Continuous voice conversation'),
                      value: _talkModeEnabled,
                      onChanged: (value) => setState(() => _talkModeEnabled = value),
                    ),
                    SwitchListTile(
                      title: const Text('Continuous Listening'),
                      subtitle: const Text('Listen without tapping'),
                      value: _continuousListening,
                      onChanged: _talkModeEnabled ? (value) => setState(() => _continuousListening = value) : null,
                    ),
                    ListTile(
                      title: const Text('Silence Threshold'),
                      subtitle: Text('${_silenceThreshold.toStringAsFixed(1)} seconds'),
                      enabled: _talkModeEnabled && _continuousListening,
                    ),
                    Slider(
                      value: _silenceThreshold,
                      min: 0.5,
                      max: 3.0,
                      divisions: 5,
                      onChanged: _talkModeEnabled && _continuousListening 
                          ? (value) => setState(() => _silenceThreshold = value) 
                          : null,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // TTS Provider Section
                _buildSection(
                  title: 'Text-to-Speech',
                  subtitle: 'Voice synthesis settings',
                  icon: Icons.speaker,
                  children: [
                    ListTile(
                      title: const Text('TTS Provider'),
                      subtitle: Text(_selectedTtsProvider.toUpperCase()),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () => _selectTtsProvider(),
                    ),
                    if (_selectedTtsProvider == 'elevenlabs') ...[
                      ListTile(
                        title: const Text('ElevenLabs API Key'),
                        subtitle: Text(
                          _elevenLabsApiKey.isEmpty 
                              ? 'Not configured' 
                              : '${_elevenLabsApiKey.substring(0, 8)}...',
                          style: TextStyle(
                            color: _elevenLabsApiKey.isEmpty ? Colors.orange : null,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(_obscureApiKey ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                        ),
                        onTap: () => _configureApiKey(),
                      ),
                    ],
                    ListTile(
                      title: const Text('Voice'),
                      subtitle: Text(_selectedVoice),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () => _selectVoice(),
                    ),
                    ListTile(
                      title: const Text('Speech Rate'),
                      subtitle: Text('${(_speechRate * 100).toInt()}%'),
                    ),
                    Slider(
                      value: _speechRate,
                      min: 0.5,
                      max: 2.0,
                      divisions: 6,
                      onChanged: (value) => setState(() => _speechRate = value),
                    ),
                    ListTile(
                      title: const Text('Pitch'),
                      subtitle: Text('${(_pitch * 100).toInt()}%'),
                    ),
                    Slider(
                      value: _pitch,
                      min: 0.5,
                      max: 2.0,
                      divisions: 6,
                      onChanged: (value) => setState(() => _pitch = value),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: OutlinedButton.icon(
                        onPressed: _testVoice,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Test Voice'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Voice Models Section
                _buildSection(
                  title: 'Speech Models',
                  subtitle: 'STT and language models',
                  icon: Icons.psychology,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.mic),
                      title: const Text('Speech-to-Text Model'),
                      subtitle: const Text('Whisper Large v3'),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () => _selectSttModel(),
                    ),
                    ListTile(
                      leading: const Icon(Icons.translate),
                      title: const Text('Language'),
                      subtitle: const Text('English (US)'),
                      trailing: const Icon(Icons.arrow_drop_down),
                    ),
                    SwitchListTile(
                      title: const Text('Auto-detect Language'),
                      subtitle: const Text('Detect spoken language automatically'),
                      value: true,
                      onChanged: (value) {},
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Quick Actions
                _buildSection(
                  title: 'Quick Actions',
                  subtitle: 'Voice shortcuts',
                  icon: Icons.flash_on,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Add Voice Command'),
                      subtitle: const Text('Create custom voice shortcuts'),
                      onTap: () => _showComingSoon('Voice Commands'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.mic_external_on),
                      title: const Text('Voice Macros'),
                      subtitle: const Text('Pre-recorded voice responses'),
                      onTap: () => _showComingSoon('Voice Macros'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Save Button
                FilledButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Settings'),
                ),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  void _editWakeWord() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wake Word'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter wake word',
            border: OutlineInputBorder(),
          ),
          controller: TextEditingController(text: _wakeWord),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              setState(() => _wakeWord = value);
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _selectTtsProvider() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('TTS Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('OpenAI'),
              subtitle: const Text('Built-in voices, API required'),
              value: 'openai',
              groupValue: _selectedTtsProvider,
              onChanged: (value) {
                setState(() => _selectedTtsProvider = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('ElevenLabs'),
              subtitle: const Text('Premium voices, API key required'),
              value: 'elevenlabs',
              groupValue: _selectedTtsProvider,
              onChanged: (value) {
                setState(() => _selectedTtsProvider = value!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Local (WhisperSpeech)'),
              subtitle: const Text('Free, runs locally'),
              value: 'local',
              groupValue: _selectedTtsProvider,
              onChanged: (value) {
                setState(() => _selectedTtsProvider = value!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _selectVoice() {
    final filteredVoices = _availableVoices.where((v) => 
      _selectedTtsProvider == 'local' || v.provider == _selectedTtsProvider
    ).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Voice'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: filteredVoices.length,
            itemBuilder: (context, index) {
              final voice = filteredVoices[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(voice.name[0]),
                ),
                title: Text(voice.name),
                subtitle: Text(voice.description),
                trailing: _selectedVoice == voice.id 
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _selectedVoice = voice.id);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _configureApiKey() {
    final controller = TextEditingController(text: _elevenLabsApiKey);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ElevenLabs API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'xi_...',
                border: OutlineInputBorder(),
              ),
              obscureText: _obscureApiKey,
            ),
            const SizedBox(height: 8),
            Text(
              'Get your API key from elevenlabs.io',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _elevenLabsApiKey = controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _selectSttModel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Speech-to-Text Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Whisper Large v3'),
              subtitle: const Text('Best accuracy, slower'),
              value: 'whisper-large-v3',
              groupValue: 'whisper-large-v3',
              onChanged: (value) => Navigator.pop(context),
            ),
            RadioListTile<String>(
              title: const Text('Whisper Medium'),
              subtitle: const Text('Good accuracy, faster'),
              value: 'whisper-medium',
              groupValue: 'whisper-large-v3',
              onChanged: (value) => Navigator.pop(context),
            ),
            RadioListTile<String>(
              title: const Text('Whisper Small'),
              subtitle: const Text('Fast, lower accuracy'),
              value: 'whisper-small',
              groupValue: 'whisper-large-v3',
              onChanged: (value) => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _testVoice() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Playing test audio...'),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon!'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Voice Configuration Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Voice Wake', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Activate DuckBot by saying the wake word. Adjust sensitivity for noisy environments.'),
              SizedBox(height: 12),
              Text('Talk Mode', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Continuous voice conversation without tapping. Set silence threshold to control when listening stops.'),
              SizedBox(height: 12),
              Text('TTS Voice', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Choose from OpenAI or ElevenLabs voices. ElevenLabs requires an API key.'),
              SizedBox(height: 12),
              Text('Tip: Use Talk Mode with headphones for hands-free operation!'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _saveSettings() {
    // Save to SharedPreferences or Gateway
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class VoiceOption {
  final String id;
  final String name;
  final String provider;
  final String description;

  VoiceOption({
    required this.id,
    required this.name,
    required this.provider,
    required this.description,
  });
}