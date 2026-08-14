import 'package:flutter/material.dart';
import 'utils/url_opener.dart';

class AutoProcessSettingsScreen extends StatefulWidget {
  const AutoProcessSettingsScreen({super.key});

  @override
  State<AutoProcessSettingsScreen> createState() => _AutoProcessSettingsScreenState();
}

class _AutoProcessSettingsScreenState extends State<AutoProcessSettingsScreen> {
  bool _autoProcess = true;
  String _selectedLanguage = 'Chinese (ចិន)';
  
  // ១. UI បង្ហាញពណ៌លឿងលើ "រកឃើញស្វ័យប្រវត្តិ" (Index 0) ជា Default
  int _selectedVoiceOption = 0; 

  // ២. តម្លៃពិតប្រាកដដែលត្រូវយកទៅប្រើប្រាស់ពេលដំណើរការ (ឧ. 2 គឺ ស្រីមុំ)
  int _targetVoiceGender = 2; // ផ្លាស់ប្តូរតាមតម្រូវការ (1: ប្រុស, 2: ស្រី)

  final TextEditingController _urlController = TextEditingController(
    text: 'https://1cce98a43bf691ad0f.gradio.live',
  );

  String get _runtimeVoiceTargetLabel {
    return _targetVoiceGender == 1 ? 'Male' : 'Female';
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final labelColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final fieldBorderColor = isDarkMode ? Colors.white24 : Colors.grey.shade300;
    final dropdownBorderColor = isDarkMode ? Colors.blueAccent : Colors.blue;
    final cardBackgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ដំណើរការដោយស្វ័យប្រវត្តិ',
          style: TextStyle(
            color: labelColor,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? cardBackgroundColor,
        iconTheme: IconThemeData(
          color: labelColor,
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ដំណើរការដោយស្វ័យប្រវត្តិ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: labelColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'បិទរាល់ពេលបើកកម្មវិធី។ បើកដើម្បីធ្វើការបកប្រែអត្ថបទ បកប្រែភាសា បង្កើតសំឡេង និងទាញយកវីដេអូដោយស្វ័យប្រវត្តិបន្ទាប់ពីជ្រើសរើសវីដេអូ។',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: _autoProcess,
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.blue,
                  onChanged: (val) => setState(() => _autoProcess = val),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ប្រើប្រាស់ Auto AI សម្រាប់អត្ថបទរង និង Google Translate អនឡាញសម្រាប់ការបកប្រែភាសាខ្មែររហ័ស។ NLLB អហ្វឡាញមិនត្រូវបានប្រើប្រាស់ក្នុងរបៀបស្វ័យប្រវត្តិទេ។',
              style: TextStyle(
                fontSize: 12,
                color: secondaryTextColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'ភាសាដើមរបស់វីដេអូ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cardBackgroundColor,
                border: Border.all(color: dropdownBorderColor, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedLanguage,
                  isExpanded: true,
                  dropdownColor: cardBackgroundColor,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: secondaryTextColor,
                  ),
                  items: ['Chinese (ចិន)', 'English', 'Spanish'].map((String lang) {
                    return DropdownMenuItem<String>(
                      value: lang,
                      child: Text(
                        lang,
                        style: TextStyle(
                          fontSize: 15,
                          color: labelColor,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedLanguage = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'ជម្រើសសំឡេងដំណើរការស្វ័យប្រវត្តិ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardBackgroundColor,
                border: Border.all(color: fieldBorderColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildSegmentButton(0, Icons.autorenew, 'រកឃើញ\nស្វ័យប្រវត្តិ', isDarkMode)),
                  Container(width: 1, height: 48, color: fieldBorderColor),
                  Expanded(child: _buildSegmentButton(1, Icons.male, 'ពិសិដ្ឋ(Piseth)\nប្រុស (Male)', isDarkMode)),
                  Container(width: 1, height: 48, color: fieldBorderColor),
                  Expanded(child: _buildSegmentButton(2, Icons.female, 'ស្រីមុំ (SreyMom)\nស្រី (Female)', isDarkMode)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Runtime target voice: $_runtimeVoiceTargetLabel',
              style: TextStyle(
                fontSize: 12,
                color: secondaryTextColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'កំណត់ជាសំឡេងប្រុស ឬសំឡេងស្រីសុទ្ធ ដើម្បីរំលងការរកឃើញភេទស្វ័យប្រវត្តិសម្រាប់វីដេអូទាំងមូល។',
              style: TextStyle(
                fontSize: 12,
                color: secondaryTextColor,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'តំណភ្ជាប់ម៉ាស៊ីនបម្រើ VoxCPM ផ្ទាល់ខ្លួន (ឧ. Google Colab)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                filled: true,
                fillColor: cardBackgroundColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: fieldBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: fieldBorderColor),
                ),
              ),
              style: TextStyle(
                fontSize: 15,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final raw = _urlController.text.trim();
                      if (raw.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a Gradio URL first')),
                        );
                        return;
                      }
                      try {
                        final ok = await openUrl(raw);
                        if (!ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not open URL')),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error opening URL: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('បើក Gradio'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'អត្ថបទនេះមានភាសាខ្មែររួចស្រេចហើយ',
              style: TextStyle(
                fontSize: 12,
                color: secondaryTextColor,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(int index, IconData icon, String label, bool isDarkMode) {
    bool isSelected = _selectedVoiceOption == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVoiceOption = index;

          // 0 = "រកឃើញស្វ័យប្រវត្តិ" -> runtime target always maps to "ស្រីមុំ (2)"
          // 1 = Male -> runtime target is 1
          // 2 = Female -> runtime target is 2
          _targetVoiceGender = index == 0 ? 2 : index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFEBC17B) 
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: index == 0 ? const Radius.circular(8) : Radius.zero,
            right: index == 2 ? const Radius.circular(8) : Radius.zero,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? Icons.check : icon,
              size: 16,
              color: isSelected ? Colors.black87 : (isDarkMode ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black87 : (isDarkMode ? Colors.white70 : Colors.black87),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}