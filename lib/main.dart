import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BukuBarangApp());
}

class BukuBarangApp extends StatefulWidget {
  const BukuBarangApp({super.key});

  @override
  State<BukuBarangApp> createState() => _BukuBarangAppState();
}

class _BukuBarangAppState extends State<BukuBarangApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryLightBlue = Color(0xFF0284C7);
    const lightBlueHeader = Color(0xFFBAE6FD);

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLightBlue,
        brightness: Brightness.light,
        primary: const Color(0xFF0284C7),
        secondary: const Color(0xFF38BDF8),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF0F9FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBlueHeader,
        foregroundColor: Color(0xFF0C4A6E),
        elevation: 0,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryLightBlue,
        brightness: Brightness.dark,
        primary: const Color(0xFF38BDF8),
        secondary: const Color(0xFF7DD3FC),
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B),
        foregroundColor: Color(0xFF7DD3FC),
        elevation: 0,
      ),
    );

    return MaterialApp(
      title: 'Buku Barang by Natanael',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: HomeScreen(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

// ---------------- MODEL DATA BARANG MASUK & UPAH ----------------
class ItemEntry {
  final String id;
  final String workerName;
  final String itemName;
  final double quantity;
  final String unit;
  final double wagePerUnit;
  final double totalWage;
  final DateTime date;
  final String note;
  final bool isPaid;

  ItemEntry({
    required this.id,
    required this.workerName,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.wagePerUnit,
    required this.totalWage,
    required this.date,
    this.note = '',
    this.isPaid = false,
  });

  ItemEntry copyWith({
    String? workerName,
    String? itemName,
    double? quantity,
    String? unit,
    double? wagePerUnit,
    double? totalWage,
    DateTime? date,
    String? note,
    bool? isPaid,
  }) {
    return ItemEntry(
      id: id,
      workerName: workerName ?? this.workerName,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      wagePerUnit: wagePerUnit ?? this.wagePerUnit,
      totalWage: totalWage ?? this.totalWage,
      date: date ?? this.date,
      note: note ?? this.note,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'workerName': workerName,
        'itemName': itemName,
        'quantity': quantity,
        'unit': unit,
        'wagePerUnit': wagePerUnit,
        'totalWage': totalWage,
        'date': date.toIso8601String(),
        'note': note,
        'isPaid': isPaid,
      };

  factory ItemEntry.fromJson(Map<String, dynamic> json) => ItemEntry(
        id: json['id'] as String,
        workerName: json['workerName'] as String,
        itemName: json['itemName'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unit: (json['unit'] as String?) ?? 'kg',
        wagePerUnit: (json['wagePerUnit'] as num).toDouble(),
        totalWage: (json['totalWage'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        note: (json['note'] as String?) ?? '',
        isPaid: (json['isPaid'] as bool?) ?? false,
      );
}

// ---------------- LAYAR UTAMA ----------------
class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onToggleTheme;

  const HomeScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ItemEntry> _entries = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedWorkerFilter = 'Semua';
  String _selectedPeriodFilter = 'Bulan Ini';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('bb_entries');
    if (raw != null) {
      try {
        final List list = jsonDecode(raw);
        _entries = list.map((e) => ItemEntry.fromJson(e)).toList();
      } catch (_) {}
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString('bb_entries', raw);
  }

  void _addEntry(ItemEntry entry) {
    setState(() {
      _entries.insert(0, entry);
    });
    _saveData();
  }

  void _updateEntry(ItemEntry entry) {
    final idx = _entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      setState(() {
        _entries[idx] = entry;
      });
      _saveData();
    }
  }

  void _deleteEntry(String id) {
    setState(() {
      _entries.removeWhere((e) => e.id == id);
    });
    _saveData();
  }

  void _togglePaidStatus(ItemEntry entry) {
    _updateEntry(entry.copyWith(isPaid: !entry.isPaid));
  }

  String formatRp(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    return formatter.format(value).replaceAll(',', '.');
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final day = d.day.toString().padLeft(2, '0');
    final month = months[d.month - 1];
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$day $month ${d.year}, $hour:$min';
  }

  List<String> get _uniqueWorkers {
    final set = <String>{'Semua'};
    for (var e in _entries) {
      if (e.workerName.trim().isNotEmpty) {
        set.add(e.workerName.trim());
      }
    }
    return set.toList();
  }

  List<ItemEntry> get _filteredEntries {
    final now = DateTime.now();
    return _entries.where((entry) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchWorker = entry.workerName.toLowerCase().contains(q);
        final matchItem = entry.itemName.toLowerCase().contains(q);
        final matchNote = entry.note.toLowerCase().contains(q);
        if (!matchWorker && !matchItem && !matchNote) return false;
      }

      if (_selectedWorkerFilter != 'Semua' && entry.workerName != _selectedWorkerFilter) {
        return false;
      }

      if (_selectedPeriodFilter == 'Hari Ini') {
        if (entry.date.year != now.year || entry.date.month != now.month || entry.date.day != now.day) {
          return false;
        }
      } else if (_selectedPeriodFilter == 'Bulan Ini') {
        if (entry.date.year != now.year || entry.date.month != now.month) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  double get _totalWage => _filteredEntries.fold(0.0, (s, e) => s + e.totalWage);
  double get _totalQuantity => _filteredEntries.fold(0.0, (s, e) => s + e.quantity);

  void _openAddEntryDialog([ItemEntry? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => AddEntrySheet(
        existingEntry: existing,
        existingWorkers: _uniqueWorkers.where((w) => w != 'Semua').toList(),
        onSave: (entry) {
          if (existing == null) {
            _addEntry(entry);
          } else {
            _updateEntry(entry);
          }
        },
      ),
    );
  }

  void _openExportScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ExportScreen(
          entries: _filteredEntries,
          allEntries: _entries,
          totalWage: _totalWage,
          totalQuantity: _totalQuantity,
          formatRp: formatRp,
          formatDate: _formatDate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'BB',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Buku Barang',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'by Natanael',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).brightness == Brightness.light
                        ? const Color(0xFF0369A1)
                        : const Color(0xFF7DD3FC),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mode Tampilan',
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: () => widget.onToggleTheme(!widget.isDarkMode),
          ),
          IconButton(
            tooltip: 'Ekspor Laporan',
            icon: const Icon(Icons.share),
            onPressed: _openExportScreen,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryBanner(),
                _buildFilterRow(),
                Expanded(child: _buildEntriesList()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF38BDF8),
        foregroundColor: const Color(0xFF0C4A6E),
        elevation: 4,
        onPressed: () => _openAddEntryDialog(),
        icon: const Icon(Icons.add, size: 22),
        label: const Text('Catat Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _buildSummaryBanner() {
    return Container(
      color: Theme.of(context).brightness == Brightness.light
          ? const Color(0xFFBAE6FD)
          : const Color(0xFF1E293B),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL KESELURUHAN UPAH',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                ),
                Text(
                  '${_filteredEntries.length} Catatan',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Rp ${formatRp(_totalWage)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Jumlah Barang', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        '${_totalQuantity.toStringAsFixed(1).replaceAll('.0', '')} unit/kg',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Filter Pekerja', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        _selectedWorkerFilter,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Column(
        children: [
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Cari pekerja, jenis barang, atau catatan...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).cardColor,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedWorkerFilter,
                      items: _uniqueWorkers.map((w) {
                        return DropdownMenuItem(value: w, child: Text('Pekerja: $w', style: const TextStyle(fontSize: 12)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedWorkerFilter = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).cardColor,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPeriodFilter,
                    items: ['Hari Ini', 'Bulan Ini', 'Semua'].map((p) {
                      return DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPeriodFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList() {
    final list = _filteredEntries;

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'Belum ada data barang masuk.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Tekan tombol + Catat Barang untuk memasukkan data pekerja.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
      itemCount: list.length,
      itemBuilder: (ctx, idx) {
        final item = list[idx];

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openAddEntryDialog(item),
            onLongPress: () => _showDeleteConfirm(item),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.workerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Rp ${formatRp(item.totalWage)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.itemName} • ${item.quantity.toStringAsFixed(1).replaceAll('.0', '')} ${item.unit}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                      Text(
                        '@ Rp ${formatRp(item.wagePerUnit)} / ${item.unit}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (item.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Catatan: ${item.note}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
                    ),
                  ],
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(item.date),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      GestureDetector(
                        onTap: () => _togglePaidStatus(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: item.isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            item.isPaid ? '✓ Upah Lunas' : '⏳ Belum Dibayar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: item.isPaid ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(ItemEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan?'),
        content: Text('Hapus data barang "${entry.itemName}" dari pekerja "${entry.workerName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _deleteEntry(entry.id);
              Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ---------------- FORMULIR INPUT / EDIT CATATAN BARANG ----------------
class AddEntrySheet extends StatefulWidget {
  final ItemEntry? existingEntry;
  final List<String> existingWorkers;
  final Function(ItemEntry) onSave;

  const AddEntrySheet({
    super.key,
    this.existingEntry,
    required this.existingWorkers,
    required this.onSave,
  });

  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<AddEntrySheet> {
  final _workerCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _wageRateCtrl = TextEditingController();
  final _totalWageCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _unit = 'kg';
  final List<String> _units = ['kg', 'pcs', 'karung', 'ikat', 'liter', 'gram', 'meter', 'kardus'];
  DateTime _date = DateTime.now();
  bool _isPaid = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      final e = widget.existingEntry!;
      _workerCtrl.text = e.workerName;
      _itemCtrl.text = e.itemName;
      _quantityCtrl.text = e.quantity.toString().replaceAll('.0', '');
      _wageRateCtrl.text = e.wagePerUnit.toString().replaceAll('.0', '');
      _totalWageCtrl.text = e.totalWage.toString().replaceAll('.0', '');
      _noteCtrl.text = e.note;
      _unit = e.unit;
      _date = e.date;
      _isPaid = e.isPaid;
    }
  }

  void _calculateTotal() {
    final q = double.tryParse(_quantityCtrl.text.replaceAll(',', '.')) ?? 0;
    final r = double.tryParse(_wageRateCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final total = q * r;
    if (total > 0) {
      _totalWageCtrl.text = total.toStringAsFixed(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.existingEntry == null ? 'Catat Barang Masuk dari Pekerja' : 'Edit Catatan Barang',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _workerCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Pekerja / Pemberi Barang *',
                hintText: 'Contoh: Pak Slamet, Budi, Joko',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            if (widget.existingWorkers.isNotEmpty) ...[
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.existingWorkers.take(6).map((w) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(w, style: const TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _workerCtrl.text = w),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),

            TextField(
              controller: _itemCtrl,
              decoration: const InputDecoration(
                labelText: 'Jenis / Nama Barang *',
                hintText: 'Contoh: Kopi, Karet, Sawit, Jagung, Padi',
                prefixIcon: Icon(Icons.inventory_2),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _quantityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _calculateTotal(),
                    decoration: const InputDecoration(
                      labelText: 'Jumlah / Kuantitas *',
                      hintText: '0.0',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    decoration: const InputDecoration(labelText: 'Satuan', border: OutlineInputBorder()),
                    items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _unit = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wageRateCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateTotal(),
                    decoration: InputDecoration(
                      labelText: 'Upah per $_unit (Rp)',
                      prefixText: 'Rp ',
                      hintText: '0',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _totalWageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Total Upah (Rp) *',
                      prefixText: 'Rp ',
                      hintText: '0',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2050),
                );
                if (d != null) {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_date),
                  );
                  setState(() {
                    _date = DateTime(d.year, d.month, d.day, t?.hour ?? _date.hour, t?.minute ?? _date.minute);
                  });
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Color(0xFF0284C7)),
                    const SizedBox(width: 10),
                    Text(
                      'Waktu: ${DateFormat('dd MMM yyyy, HH:mm').format(_date)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    const Text('Ubah', style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan Tambahan (Opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tandai Upah Sudah Dibayarkan', style: TextStyle(fontSize: 14)),
              value: _isPaid,
              activeColor: const Color(0xFF0284C7),
              onChanged: (val) => setState(() => _isPaid = val ?? false),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0C4A6E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final worker = _workerCtrl.text.trim();
                  final item = _itemCtrl.text.trim();
                  final q = double.tryParse(_quantityCtrl.text.replaceAll(',', '.')) ?? 0;
                  final wageRate = double.tryParse(_wageRateCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
                  var total = double.tryParse(_totalWageCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? (q * wageRate);

                  if (worker.isEmpty || item.isEmpty || q <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Harap lengkapi Nama Pekerja, Jenis Barang, dan Jumlah!')),
                    );
                    return;
                  }

                  final newEntry = ItemEntry(
                    id: widget.existingEntry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    workerName: worker,
                    itemName: item,
                    quantity: q,
                    unit: _unit,
                    wagePerUnit: wageRate,
                    totalWage: total,
                    date: _date,
                    note: _noteCtrl.text.trim(),
                    isPaid: _isPaid,
                  );

                  widget.onSave(newEntry);
                  Navigator.pop(context);
                },
                child: const Text('Simpan Data Barang & Upah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- LAYAR EKSPOR SPREADSHEET & DOKUMEN ----------------
class ExportScreen extends StatelessWidget {
  final List<ItemEntry> entries;
  final List<ItemEntry> allEntries;
  final double totalWage;
  final double totalQuantity;
  final String Function(double) formatRp;
  final String Function(DateTime) formatDate;

  const ExportScreen({
    super.key,
    required this.entries,
    required this.allEntries,
    required this.totalWage,
    required this.totalQuantity,
    required this.formatRp,
    required this.formatDate,
  });

  Future<void> _exportCsv(BuildContext context) async {
    final csv = StringBuffer();
    csv.writeln('No,Tanggal,Nama Pekerja,Jenis Barang,Jumlah,Satuan,Upah per Satuan,Total Upah,Status Upah,Catatan');

    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final status = e.isPaid ? 'Lunas' : 'Belum Dibayar';
      final dStr = formatDate(e.date);
      csv.writeln('${i + 1},"$dStr","${e.workerName}","${e.itemName}",${e.quantity},"${e.unit}",${e.wagePerUnit},${e.totalWage},"$status","${e.note.replaceAll('"', '""')}"');
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Laporan_Buku_Barang.csv');
      await file.writeAsString(csv.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Buku Barang (Spreadsheet CSV) by Natanael',
      );
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: csv.toString()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan CSV berhasil disalin ke clipboard!')),
        );
      }
    }
  }

  Future<void> _exportDoc(BuildContext context) async {
    final doc = StringBuffer();
    doc.writeln('<html><head><meta charset="utf-8"><title>Laporan Buku Barang by Natanael</title>');
    doc.writeln('<style>');
    doc.writeln('body { font-family: sans-serif; padding: 25px; color: #0F172A; }');
    doc.writeln('h1 { color: #0284C7; margin-bottom: 2px; }');
    doc.writeln('.sub { color: #64748B; font-size: 13px; margin-bottom: 20px; }');
    doc.writeln('.summary { background-color: #F0F9FF; border: 1px solid #BAE6FD; border-radius: 8px; padding: 15px; margin-bottom: 25px; }');
    doc.writeln('table { width: 100%; border-collapse: collapse; margin-top: 15px; }');
    doc.writeln('th, td { border: 1px solid #CBD5E1; padding: 8px; text-align: left; font-size: 12px; }');
    doc.writeln('th { background-color: #BAE6FD; color: #0C4A6E; font-weight: bold; }');
    doc.writeln('tr:nth-child(even) { background-color: #F8FAFC; }');
    doc.writeln('.wage { font-weight: bold; color: #0284C7; }');
    doc.writeln('</style></head><body>');
    doc.writeln('<h1>Buku Barang (BB)</h1>');
    doc.writeln('<div class="sub">Laporan Penerimaan Barang & Rekap Upah Pekerja • Dikelola oleh: Natanael • Tanggal Cetak: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}</div>');
    doc.writeln('<div class="summary">');
    doc.writeln('<p><strong>Total Keseluruhan Upah:</strong> Rp ${formatRp(totalWage)}</p>');
    doc.writeln('<p><strong>Total Jumlah Barang:</strong> ${totalQuantity.toStringAsFixed(1).replaceAll('.0', '')} unit/kg</p>');
    doc.writeln('<p><strong>Total Catatan:</strong> ${entries.length} data</p>');
    doc.writeln('</div>');
    doc.writeln('<h3>Rincian Barang Masuk & Upah Pekerja</h3>');
    doc.writeln('<table><tr><th>No</th><th>Tanggal</th><th>Nama Pekerja</th><th>Jenis Barang</th><th>Jumlah</th><th>Tarif Upah</th><th>Total Upah</th><th>Status</th></tr>');

    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final status = e.isPaid ? 'Lunas' : 'Belum Dibayar';
      final dStr = formatDate(e.date);
      doc.writeln('<tr><td>${i + 1}</td><td>$dStr</td><td><strong>${e.workerName}</strong></td><td>${e.itemName}</td><td>${e.quantity} ${e.unit}</td><td>Rp ${formatRp(e.wagePerUnit)}</td><td class="wage">Rp ${formatRp(e.totalWage)}</td><td>$status</td></tr>');
    }

    doc.writeln('</table></body></html>');

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Laporan_Buku_Barang.doc');
      await file.writeAsString(doc.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Buku Barang (Dokumen Word) by Natanael',
      );
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: doc.toString()));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Laporan Dokumen berhasil disalin ke clipboard!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Ekspor Laporan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Buku Barang by Natanael', style: TextStyle(fontSize: 11, color: Color(0xFF0369A1))),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ringkasan Data Siap Ekspor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Jumlah data tersaring: ${entries.length} catatan barang.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  Text('Total Upah: Rp ${formatRp(totalWage)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7))),
                  const SizedBox(height: 4),
                  const Text('Pilih format di bawah untuk membagikan atau membukanya di aplikasi kantor.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0F2FE),
                child: Icon(Icons.table_chart, color: Color(0xFF0284C7)),
              ),
              title: const Text('Ekspor File Spreadsheet (.csv)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Bisa dibuka langsung di Microsoft Excel & Google Sheets', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.share, color: Color(0xFF0284C7)),
              onTap: () => _exportCsv(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(Icons.description, color: Color(0xFF2563EB)),
              ),
              title: const Text('Ekspor File Dokumen (.doc / Word)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Format tabel rapi untuk Microsoft Word & WPS Office', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.share, color: Color(0xFF2563EB)),
              onTap: () => _exportDoc(context),
            ),
          ),
        ],
      ),
    );
  }
}
