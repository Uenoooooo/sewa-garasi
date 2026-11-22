import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/constants/enums.dart';
import 'package:sewa_garasi/core/utils/currency_formatter.dart';
import 'package:sewa_garasi/core/utils/date_helper.dart';
import 'package:sewa_garasi/repositories/report_repository.dart';
import 'package:sewa_garasi/viewmodels/report_view_model.dart';
import 'package:sewa_garasi/views/components/app_card.dart';
import 'package:sewa_garasi/views/components/empty_state.dart';
import 'package:sewa_garasi/views/components/info_row.dart';
import 'package:sewa_garasi/views/components/type_icons.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  int _dataTab = 0;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final vm = context.read<ReportViewModel>();
    await vm.loadAvailablePeriods();
    if (!mounted) return;
    final now = DateTime.now();
    final years = vm.availableYears;
    if (years.isNotEmpty) {
      final year = years.contains(now.year) ? now.year : years.first;
      final months = vm.monthsOf(year);
      setState(() {
        _year = year;
        _month = months.contains(now.month) ? now.month : months.last;
      });
    }
    await _load();
  }

  void _selectYear(int year) {
    final months = context.read<ReportViewModel>().monthsOf(year);
    setState(() {
      _year = year;
      if (months.isNotEmpty && !months.contains(_month)) _month = months.last;
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() {
    final vm = context.read<ReportViewModel>();
    _dataTab = _tabs.index;
    switch (_tabs.index) {
      case 0:
        return vm.loadMonthlyReport(_year);
      case 1:
        return vm.loadDailyReport(_year, _month);
      case 2:
        return vm.loadReportByGarageType();
      default:
        return vm.loadReportByTenant();
    }
  }

  _RowView _view(ReportRow row) {
    final raw = row.label;
    try {
      switch (_dataTab) {
        case 0:
          final month = int.parse(raw);
          final name = DateHelper.monthName(month);
          return _RowView(
            title: '$name $_year',
            leading: LeadingBox(text: name.substring(0, 3)),
          );
        case 1:
          final date = DateHelper.fromDb(raw);
          return _RowView(
            title: DateHelper.display(date),
            leading: LeadingBox(text: '${date.day}'),
          );
        case 2:
          final type = GarageType.values.byName(raw);
          return _RowView(
            title: type.label,
            leading: LeadingBox(icon: type.icon),
          );
        default:
          final i = raw.lastIndexOf(' (');
          final name = i > 0 ? raw.substring(0, i) : raw;
          final email = i > 0 && raw.endsWith(')')
              ? raw.substring(i + 2, raw.length - 1)
              : null;
          return _RowView(
            title: name,
            subtitle: email,
            leading: LeadingBox(
                text: name.isEmpty ? '?' : name.trim()[0].toUpperCase()),
          );
      }
    } catch (_) {
      return _RowView(title: raw, leading: const LeadingBox(text: '?'));
    }
  }

  String get _periodLabel => switch (_dataTab) {
        0 => 'Tahun $_year',
        1 => '${DateHelper.monthName(_month)} $_year',
        _ => 'Sepanjang waktu',
      };

  String get _groupLabel =>
      const ['Bulan', 'Hari', 'Tipe Garasi', 'Penyewa'][_dataTab];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Sewa Garasi'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          tabs: const [
            Tab(text: 'Bulanan'),
            Tab(text: 'Harian'),
            Tab(text: 'Tipe Garasi'),
            Tab(text: 'Penyewa'),
          ],
        ),
      ),
      body: Column(
        children: [
          AnimatedBuilder(
            animation: _tabs,
            builder: (_, __) => _filters(),
          ),
          Expanded(child: _body(vm)),
        ],
      ),
    );
  }

  Widget _body(ReportViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.errorMessage != null) {
      return EmptyState(message: vm.errorMessage!, icon: Icons.error_outline);
    }
    if (vm.reportRows.isEmpty) {
      final message = vm.availableYears.isEmpty
          ? 'Belum ada transaksi sewa.'
          : 'Belum ada data untuk periode ini.';
      return EmptyState(message: message, icon: Icons.bar_chart_outlined);
    }
    return RefreshIndicator(
      onRefresh: _init,
      child: _content(vm.reportRows, vm.totalRevenue),
    );
  }

  Widget _filters() {
    if (_tabs.index > 1) return const SizedBox(height: 4);
    final vm = context.watch<ReportViewModel>();
    final years = vm.availableYears;
    if (years.isEmpty || !years.contains(_year)) {
      return const SizedBox(height: 4);
    }
    final months = vm.monthsOf(_year);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _dropdown<int>(
              label: 'Tahun',
              value: _year,
              items: {for (final y in years) y: '$y'},
              onChanged: _selectYear,
            ),
          ),
          if (_tabs.index == 1) ...[
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _dropdown<int>(
                label: 'Bulan',
                value: months.contains(_month) ? _month : months.last,
                items: {for (final m in months) m: DateHelper.monthName(m)},
                onChanged: (v) {
                  setState(() => _month = v);
                  _load();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          items: items.entries
              .map((e) => DropdownMenuItem(
                  value: e.key, child: Text(e.value, softWrap: false)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _content(List<ReportRow> rows, int total) {
    final rentals = rows.fold<int>(0, (a, r) => a + r.rentalCount);
    final extensions = rows.fold<int>(0, (a, r) => a + r.extensionCount);
    final top = rows.reduce((a, b) => b.revenue > a.revenue ? b : a);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SummaryBanner(
          period: _periodLabel,
          total: total,
          rentals: rentals,
          extensions: extensions,
          topLabel: rows.length > 1 ? _view(top).title : null,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text('Rincian per $_groupLabel',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            Text('${rows.length} data',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        const Text('Ketuk kartu untuk melihat detail',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 12),
        for (final row in rows) ...[
          _ReportCard(
            view: _view(row),
            row: row,
            share: total == 0 ? 0 : row.revenue / total,
            isTop: rows.length > 1 && identical(row, top),
            onTap: () => _showDetail(row, total),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  void _showDetail(ReportRow row, int total) {
    final view = _view(row);
    final share = total == 0 ? 0.0 : row.revenue / total;
    final avg =
        row.transactionCount == 0 ? 0 : row.revenue ~/ row.transactionCount;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  view.leading,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(view.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 18)),
                        Text(view.subtitle ?? 'Laporan per $_groupLabel',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              NoticeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pendapatan',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(CurrencyFormatter.rupiah(row.revenue),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 26)),
                    const SizedBox(height: 4),
                    Text(
                        '${_percent(share)} dari total '
                        '${CurrencyFormatter.rupiah(total)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Komposisi Pendapatan',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _CompositionBar(
                  rental: row.rentalRevenue, extension: row.extensionRevenue),
              const SizedBox(height: 12),
              _LegendRow(
                color: AppColors.primary,
                label: 'Sewa baru (${row.rentalCount}x)',
                value: CurrencyFormatter.rupiah(row.rentalRevenue),
              ),
              _LegendRow(
                color: AppColors.warning,
                label: 'Perpanjangan (${row.extensionCount}x)',
                value: CurrencyFormatter.rupiah(row.extensionRevenue),
              ),
              const Divider(height: 28),
              InfoRow(
                  label: 'Total transaksi',
                  value: '${row.transactionCount} transaksi'),
              InfoRow(
                  label: 'Rata-rata per transaksi',
                  value: CurrencyFormatter.rupiah(avg)),
            ],
          ),
        ),
      ),
    );
  }
}

String _percent(double share) {
  final p = share * 100;
  return '${p >= 10 || p == 0 ? p.round() : p.toStringAsFixed(1)}%';
}

class _RowView {
  const _RowView({required this.title, required this.leading, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget leading;
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.period,
    required this.total,
    required this.rentals,
    required this.extensions,
    this.topLabel,
  });

  final String period;
  final int total;
  final int rentals;
  final int extensions;
  final String? topLabel;

  @override
  Widget build(BuildContext context) {
    final white70 = Colors.white.withValues(alpha: 0.8);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Pendapatan • $period',
              style: TextStyle(color: white70, fontSize: 13)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(CurrencyFormatter.rupiah(total),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 28)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _BannerStat(
                      icon: Icons.add_business_outlined,
                      value: '$rentals',
                      label: 'Sewa baru')),
              const SizedBox(width: 10),
              Expanded(
                  child: _BannerStat(
                      icon: Icons.event_repeat_outlined,
                      value: '$extensions',
                      label: 'Perpanjangan')),
            ],
          ),
          if (topLabel != null) ...[
            const SizedBox(height: 12),
            Text('Tertinggi: $topLabel',
                style: TextStyle(color: white70, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat(
      {required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.view,
    required this.row,
    required this.share,
    required this.isTop,
    required this.onTap,
  });

  final _RowView view;
  final ReportRow row;
  final double share;
  final bool isTop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final counts = [
      '${row.rentalCount} sewa',
      if (row.extensionCount > 0) '${row.extensionCount} perpanjangan',
    ].join(' • ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  view.leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(view.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15)),
                        if (view.subtitle != null)
                          Text(view.subtitle!,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(counts,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(CurrencyFormatter.rupiah(row.revenue),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: share.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: AppColors.primaryLight,
                        color: isTop ? AppColors.primary : AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 44,
                    child: Text(_percent(share),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
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

class _CompositionBar extends StatelessWidget {
  const _CompositionBar({required this.rental, required this.extension});

  final int rental;
  final int extension;

  @override
  Widget build(BuildContext context) {
    final total = rental + extension;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: total == 0
            ? Container(color: AppColors.border)
            : Row(
                children: [
                  if (rental > 0)
                    Expanded(
                        flex: rental,
                        child: Container(color: AppColors.primary)),
                  if (rental > 0 && extension > 0) const SizedBox(width: 2),
                  if (extension > 0)
                    Expanded(
                        flex: extension,
                        child: Container(color: AppColors.warning)),
                ],
              ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(
      {required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.textSecondary))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
