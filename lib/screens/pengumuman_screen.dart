import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import '../services/api_service.dart';
import '../helpers/hari_besar.dart';

// ── Model ─────────────────────────────────────────────────────
class Pengumuman {
  final int    id;
  final String judul;
  final String isi;
  final String emoji;
  final String? tanggalEvent;
  final String createdAt;
  final String namaPembuat;
  final int    idUser;
  final int    jumlahKomentar;

  Pengumuman({
    required this.id,
    required this.judul,
    required this.isi,
    required this.emoji,
    this.tanggalEvent,
    required this.createdAt,
    required this.namaPembuat,
    required this.idUser,
    required this.jumlahKomentar,
  });

  factory Pengumuman.fromJson(Map<String, dynamic> j) => Pengumuman(
    id:             int.tryParse(j['id'].toString()) ?? 0,
    judul:          j['judul']          ?? '',
    isi:            j['isi']            ?? '',
    emoji:          j['emoji']          ?? '📢',
    tanggalEvent:   j['tanggal_event'],
    createdAt:      j['created_at']     ?? '',
    namaPembuat:    j['nama_pembuat']   ?? '-',
    idUser:         int.tryParse(j['id_user'].toString()) ?? 0,
    jumlahKomentar: int.tryParse(
        j['jumlah_komentar'].toString()) ?? 0,
  );
}

class Komentar {
  final int    id;
  final String isi;
  final String createdAt;
  final String namaUser;
  final int    idUser;

  Komentar({
    required this.id,
    required this.isi,
    required this.createdAt,
    required this.namaUser,
    required this.idUser,
  });

  factory Komentar.fromJson(Map<String, dynamic> j) => Komentar(
    id:        int.tryParse(j['id'].toString()) ?? 0,
    isi:       j['isi']       ?? '',
    createdAt: j['created_at'] ?? '',
    namaUser:  j['nama_user'] ?? '-',
    idUser:    int.tryParse(j['id_user'].toString()) ?? 0,
  );
}

// ── List Pengumuman ───────────────────────────────────────────
class PengumumanScreen extends StatefulWidget {
  const PengumumanScreen({super.key});

  @override
  State<PengumumanScreen> createState() => _PengumumanScreenState();
}

class _PengumumanScreenState extends State<PengumumanScreen> {
  List<Pengumuman> _list   = [];
  bool   _loading          = false;
  String _filter           = 'semua';
  int?   _myUserId;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _load();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('user_data');
    if (raw != null) {
      final user = jsonDecode(raw);
      setState(() => _myUserId =
          int.tryParse(user['id'].toString()));
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.getPengumuman(filter: _filter);
    if (res['status'] == true) {
      final list = (res['data'] as List)
          .map((e) => Pengumuman.fromJson(e))
          .toList();
      setState(() { _list = list; _loading = false; });
    } else {
      setState(() => _loading = false);
    }
  }

  void _showForm({Pengumuman? existing}) {
    final judulCtrl   = TextEditingController(text: existing?.judul ?? '');
    final isiCtrl     = TextEditingController(text: existing?.isi   ?? '');
    String emoji      = existing?.emoji ?? '📢';
    DateTime? tanggal = existing?.tanggalEvent != null
        ? DateTime.tryParse(existing!.tanggalEvent!)
        : null;

    final emojis = ['📢','📅','🎉','⚠️','📚','🏫','🕌','🌙',
                    '⭐','🎊','🏆','📝','💡','🔔','❗','✅'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16, left: 16, right: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Buat Pengumuman',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Pilih emoji
                SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: emojis.length,
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => setModal(() => emoji = emojis[i]),
                      child: Container(
                        width: 44, height: 44,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: emoji == emojis[i]
                              ? const Color(0xFF1B5E20).withOpacity(0.15)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: emoji == emojis[i]
                                ? const Color(0xFF1B5E20)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(emojis[i],
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Judul
                TextField(
                  controller: judulCtrl,
                  decoration: InputDecoration(
                    labelText: 'Judul *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: Text(emoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(height: 12),

                // Isi
                TextField(
                  controller: isiCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Isi Pengumuman *',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Tanggal event (opsional)
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: tanggal ?? DateTime.now(),
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(
                              primary: Color(0xFF1B5E20)),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setModal(() => tanggal = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event,
                            color: Color(0xFF1B5E20), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tanggal != null
                                ? '${HariBesarHelper.namaHari(tanggal!)},'
                                  ' ${tanggal!.day}'
                                  ' ${HariBesarHelper.namaBulan(tanggal!.month)}'
                                  ' ${tanggal!.year}'
                                : 'Tanggal event (opsional)',
                            style: TextStyle(
                                color: tanggal != null
                                    ? Colors.black87
                                    : Colors.grey),
                          ),
                        ),
                        if (tanggal != null)
                          GestureDetector(
                            onTap: () => setModal(() => tanggal = null),
                            child: const Icon(Icons.close,
                                size: 18, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Tombol simpan
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (judulCtrl.text.trim().isEmpty ||
                          isiCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Judul dan isi wajib diisi')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      final res = await ApiService.buatPengumuman(
                        judul: judulCtrl.text.trim(),
                        isi:   isiCtrl.text.trim(),
                        emoji: emoji,
                        tanggalEvent: tanggal != null
                            ? '${tanggal!.year}-'
                              '${tanggal!.month.toString().padLeft(2, '0')}-'
                              '${tanggal!.day.toString().padLeft(2, '0')}'
                            : null,
                      );
                      if (res['status'] == true) {
                        _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Pengumuman berhasil dibuat'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Posting'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _waktuRelatif(String createdAt) {
    try {
      final dt      = DateTime.parse(createdAt);
      final selisih = DateTime.now().difference(dt);
      if (selisih.inMinutes  < 1)  return 'Baru saja';
      if (selisih.inMinutes  < 60) return '${selisih.inMinutes} menit lalu';
      if (selisih.inHours    < 24) return '${selisih.inHours} jam lalu';
      if (selisih.inDays     < 7)  return '${selisih.inDays} hari lalu';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return createdAt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Pengumuman'),
      ),
      body: Column(
        children: [
          // Filter
          Container(
            color: const Color(0xFF1B5E20),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                _filterChip('Semua',      'semua'),
                const SizedBox(width: 8),
                _filterChip('Hari Ini',   'hari_ini'),
                const SizedBox(width: 8),
                _filterChip('Minggu Ini', 'minggu_ini'),
                const SizedBox(width: 8),
                _filterChip('Mendatang',  'mendatang'),
              ],
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.campaign_outlined,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Belum ada pengumuman',
                                style:
                                    TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _list.length,
                          itemBuilder: (_, i) =>
                              _buildItem(_list[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showForm,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Buat Pengumuman'),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = value);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: active
                    ? const Color(0xFF1B5E20)
                    : Colors.white,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildItem(Pengumuman p) {
    final hasEvent = p.tanggalEvent != null &&
        p.tanggalEvent!.isNotEmpty;
    DateTime? eventDt;
    if (hasEvent) eventDt = DateTime.tryParse(p.tanggalEvent!);
    final selisih = eventDt != null
        ? eventDt.difference(DateTime.now()).inDays
        : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPengumumanScreen(
            pengumuman: p,
            myUserId:   _myUserId,
            onDeleted:  _load,
          ),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(p.emoji,
                      style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.judul,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        Text(p.namaPembuat,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(_waktuRelatif(p.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              Text(p.isi,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Tanggal event
                  if (hasEvent && eventDt != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (selisih != null && selisih <= 3)
                            ? Colors.red.withOpacity(0.1)
                            : const Color(0xFF1B5E20)
                                .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event,
                              size: 12,
                              color: (selisih != null &&
                                      selisih <= 3)
                                  ? Colors.red
                                  : const Color(0xFF1B5E20)),
                          const SizedBox(width: 4),
                          Text(
                            selisih == 0
                                ? 'Hari ini'
                                : selisih != null && selisih > 0
                                    ? '$selisih hari lagi'
                                    : '${eventDt.day}/${eventDt.month}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: (selisih != null &&
                                        selisih <= 3)
                                    ? Colors.red
                                    : const Color(0xFF1B5E20)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  // Jumlah komentar
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${p.jumlahKomentar}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detail + Chat ─────────────────────────────────────────────
class DetailPengumumanScreen extends StatefulWidget {
  final Pengumuman  pengumuman;
  final int?        myUserId;
  final VoidCallback onDeleted;

  const DetailPengumumanScreen({
    super.key,
    required this.pengumuman,
    required this.myUserId,
    required this.onDeleted,
  });

  @override
  State<DetailPengumumanScreen> createState() =>
      _DetailPengumumanScreenState();
}

class _DetailPengumumanScreenState
    extends State<DetailPengumumanScreen> {
  List<Komentar>  _komentar  = [];
  bool            _loading   = false;
  bool            _kirim     = false;
  final _inputCtrl           = TextEditingController();
  final _scrollCtrl          = ScrollController();
  Timer?          _timer;

  @override
  void initState() {
    super.initState();
    _loadKomentar();
    // Polling tiap 5 detik
    _timer = Timer.periodic(
        const Duration(seconds: 5), (_) => _loadKomentar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadKomentar() async {
    final res = await ApiService.getKomentar(widget.pengumuman.id);
    if (res['status'] == true && mounted) {
      final list = (res['data'] as List)
          .map((e) => Komentar.fromJson(e))
          .toList();
      setState(() => _komentar = list);
    }
  }

  Future<void> _kirimKomentar() async {
    final isi = _inputCtrl.text.trim();
    if (isi.isEmpty) return;
    setState(() => _kirim = true);
    _inputCtrl.clear();

    final res = await ApiService.kirimKomentar(
        widget.pengumuman.id, isi);
    setState(() => _kirim = false);

    if (res['status'] == true) {
      await _loadKomentar();
      // Scroll ke bawah
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _hapus() async {
    final konfirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pengumuman'),
        content:
            const Text('Yakin ingin menghapus pengumuman ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (konfirm != true) return;

    final res =
        await ApiService.hapusPengumuman(widget.pengumuman.id);
    if (res['status'] == true && mounted) {
      widget.onDeleted();
      Navigator.pop(context);
    }
  }

  String _waktuRelatif(String createdAt) {
    try {
      final dt      = DateTime.parse(createdAt);
      final selisih = DateTime.now().difference(dt);
      if (selisih.inMinutes  < 1)  return 'Baru saja';
      if (selisih.inMinutes  < 60) return '${selisih.inMinutes}m';
      if (selisih.inHours    < 24) return '${selisih.inHours}j';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p        = widget.pengumuman;
    final isOwner  = widget.myUserId == p.idUser;
    final hasEvent = p.tanggalEvent != null &&
        p.tanggalEvent!.isNotEmpty;
    DateTime? eventDt;
    if (hasEvent) eventDt = DateTime.tryParse(p.tanggalEvent!);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Text('Detail Pengumuman'),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _hapus,
            ),
        ],
      ),
      body: Column(
        children: [
          // Detail pengumuman
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.emoji,
                        style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.judul,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.person,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(p.namaPembuat,
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12)),
                              const SizedBox(width: 12),
                              const Icon(Icons.access_time,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(_waktuRelatif(p.createdAt),
                                  style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Tanggal event
                if (hasEvent && eventDt != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF1B5E20)
                              .withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event,
                            color: Color(0xFF1B5E20), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${HariBesarHelper.namaHari(eventDt)},'
                          ' ${eventDt.day}'
                          ' ${HariBesarHelper.namaBulan(eventDt.month)}'
                          ' ${eventDt.year}',
                          style: const TextStyle(
                              color: Color(0xFF1B5E20),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(p.isi,
                    style: const TextStyle(
                        fontSize: 14, height: 1.5)),
              ],
            ),
          ),

          const Divider(height: 1),

          // Header komentar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline,
                    size: 16, color: Color(0xFF1B5E20)),
                const SizedBox(width: 8),
                Text(
                  '${_komentar.length} Komentar',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // List komentar
          Expanded(
            child: _komentar.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('Belum ada komentar',
                            style:
                                TextStyle(color: Colors.grey[500])),
                        const SizedBox(height: 4),
                        const Text('Jadilah yang pertama berkomentar!',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _komentar.length,
                    itemBuilder: (_, i) =>
                        _buildKomentar(_komentar[i]),
                  ),
          ),

          // Input komentar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: InputDecoration(
                        hintText: 'Tulis komentar...',
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _kirimKomentar(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _kirim ? null : _kirimKomentar,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        shape: BoxShape.circle,
                      ),
                      child: _kirim
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                          : const Icon(Icons.send,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKomentar(Komentar k) {
    final isMe = widget.myUserId == k.idUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF1B5E20),
              child: Text(
                k.namaUser.isNotEmpty
                    ? k.namaUser[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 4, bottom: 2),
                    child: Text(k.namaUser,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B5E20))),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF1B5E20)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(16),
                      topRight:    const Radius.circular(16),
                      bottomLeft:  Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text(k.isi,
                      style: TextStyle(
                          fontSize: 13,
                          color: isMe
                              ? Colors.white
                              : Colors.black87)),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      top: 2, left: 4, right: 4),
                  child: Text(_waktuRelatif(k.createdAt),
                      style: const TextStyle(
                          fontSize: 10, color: Colors.grey)),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}