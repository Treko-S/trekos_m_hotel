import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:trekos_m_hotel/core/theme/app_theme.dart';
import 'package:trekos_m_hotel/features/hotel_search/domain/entities/filter_criteria.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_bloc.dart';
import 'package:trekos_m_hotel/features/hotel_search/presentation/bloc/hotel_event.dart';

class AdvancedFiltersModal extends StatefulWidget {
  final AdvancedFilterCriteria currentCriteria;

  const AdvancedFiltersModal({
    super.key,
    required this.currentCriteria,
  });

  static Future<void> show(BuildContext context) {
    final current = context.read<HotelBloc>().state.advancedFilters;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdvancedFiltersModal(currentCriteria: current),
    );
  }

  @override
  State<AdvancedFiltersModal> createState() => _AdvancedFiltersModalState();
}

class _AdvancedFiltersModalState extends State<AdvancedFiltersModal> {
  late double _minPrice;
  late double _maxPrice;
  late String? _roomType;
  late int _minCapacity;
  late int? _floor;
  late bool _requireAc;
  late bool _requireWifi;
  late bool _requireTv;
  late bool _requireMinibar;
  late bool _requireJacuzzi;
  late bool _requireBalcony;

  final currencyFormat = NumberFormat.currency(locale: 'es_PY', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _minPrice = widget.currentCriteria.minPrice;
    _maxPrice = widget.currentCriteria.maxPrice;
    _roomType = widget.currentCriteria.roomType;
    _minCapacity = widget.currentCriteria.minCapacity;
    _floor = widget.currentCriteria.floor;
    _requireAc = widget.currentCriteria.requireAc;
    _requireWifi = widget.currentCriteria.requireWifi;
    _requireTv = widget.currentCriteria.requireTv;
    _requireMinibar = widget.currentCriteria.requireMinibar;
    _requireJacuzzi = widget.currentCriteria.requireJacuzzi;
    _requireBalcony = widget.currentCriteria.requireBalcony;
  }

  void _reset() {
    setState(() {
      _minPrice = 150000.0;
      _maxPrice = 1000000.0;
      _roomType = 'ALL';
      _minCapacity = 1;
      _floor = null;
      _requireAc = false;
      _requireWifi = false;
      _requireTv = false;
      _requireMinibar = false;
      _requireJacuzzi = false;
      _requireBalcony = false;
    });
  }

  void _apply() {
    final criteria = AdvancedFilterCriteria(
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      roomType: _roomType == 'ALL' ? null : _roomType,
      minCapacity: _minCapacity,
      floor: _floor,
      requireAc: _requireAc,
      requireWifi: _requireWifi,
      requireTv: _requireTv,
      requireMinibar: _requireMinibar,
      requireJacuzzi: _requireJacuzzi,
      requireBalcony: _requireBalcony,
    );

    context.read<HotelBloc>().add(HotelAdvancedFilterChanged(criteria));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Moderno
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppTheme.primaryDark),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Filtros de Búsqueda',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _reset,
                  child: Text(
                    'Limpiar',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Opciones de Filtro
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==========================================
                  // 1. RANGO DE PRECIO (DESDE - HASTA)
                  // ==========================================
                  Text(
                    'Rango de Precio por Noche',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryDark),
                  ),
                  const SizedBox(height: 12),

                  // Cajas informativas Desde / Hasta
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('DESDE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${currencyFormat.format(_minPrice)} Gs.',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('HASTA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${currencyFormat.format(_maxPrice)} Gs.',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // RangeSlider con nuevo tema Azul Moderno
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppTheme.primaryBlue,
                      inactiveTrackColor: const Color(0xFFE2E8F0),
                      thumbColor: AppTheme.primaryBlue,
                      overlayColor: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10),
                      rangeValueIndicatorShape: const PaddleRangeSliderValueIndicatorShape(),
                    ),
                    child: RangeSlider(
                      values: RangeValues(_minPrice, _maxPrice),
                      min: 150000.0,
                      max: 1000000.0,
                      divisions: 17,
                      labels: RangeLabels(
                        '${currencyFormat.format(_minPrice)} Gs.',
                        '${currencyFormat.format(_maxPrice)} Gs.',
                      ),
                      onChanged: (RangeValues values) {
                        setState(() {
                          _minPrice = values.start;
                          _maxPrice = values.end;
                        });
                      },
                    ),
                  ),

                  // Presets rápidos de precios
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPricePreset('Cualquiera', 150000.0, 1000000.0),
                      _buildPricePreset('Hasta 200k', 150000.0, 200000.0),
                      _buildPricePreset('200k - 400k', 200000.0, 400000.0),
                      _buildPricePreset('Más de 400k', 400000.0, 1000000.0),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // ==========================================
                  // 2. TIPO DE HABITACIÓN
                  // ==========================================
                  Text(
                    'Tipo de Habitación',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryDark),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChoiceChip('Todas', _roomType == null || _roomType == 'ALL', () => setState(() => _roomType = 'ALL')),
                      _buildChoiceChip('Standard Single', _roomType == 'Standard Single', () => setState(() => _roomType = 'Standard Single')),
                      _buildChoiceChip('Doble Superior', _roomType == 'Doble Superior', () => setState(() => _roomType = 'Doble Superior')),
                      _buildChoiceChip('Suite Presidencial', _roomType == 'Suite Presidencial', () => setState(() => _roomType = 'Suite Presidencial')),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // ==========================================
                  // 3. CAPACIDAD DE PERSONAS / CAMAS
                  // ==========================================
                  Text(
                    'Capacidad Mínima',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryDark),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildCapacityCard(1, '1+ Huésped', Icons.person_outline),
                      const SizedBox(width: 10),
                      _buildCapacityCard(2, '2+ Huéspedes', Icons.people_outline),
                      const SizedBox(width: 10),
                      _buildCapacityCard(4, '4+ Huéspedes', Icons.groups_outlined),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // ==========================================
                  // 4. UBICACIÓN POR PISO
                  // ==========================================
                  Text(
                    'Piso de Ubicación',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryDark),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChoiceChip('Todos', _floor == null, () => setState(() => _floor = null)),
                      _buildChoiceChip('Piso 1', _floor == 1, () => setState(() => _floor = 1)),
                      _buildChoiceChip('Piso 2', _floor == 2, () => setState(() => _floor = 2)),
                      _buildChoiceChip('Piso 3', _floor == 3, () => setState(() => _floor = 3)),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),

                  // ==========================================
                  // 5. SERVICIOS Y COMODIDADES DESEADAS
                  // ==========================================
                  Text(
                    'Servicios & Equipamiento Incluido',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryDark),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildAmenityChip('Aire Acondicionado', Icons.ac_unit, _requireAc, (v) => setState(() => _requireAc = v)),
                      _buildAmenityChip('WiFi Alta Velocidad', Icons.wifi, _requireWifi, (v) => setState(() => _requireWifi = v)),
                      _buildAmenityChip('Smart TV 55"', Icons.tv, _requireTv, (v) => setState(() => _requireTv = v)),
                      _buildAmenityChip('Frigobar / Minibar', Icons.kitchen, _requireMinibar, (v) => setState(() => _requireMinibar = v)),
                      _buildAmenityChip('Jacuzzi Hidromasaje', Icons.bathtub_outlined, _requireJacuzzi, (v) => setState(() => _requireJacuzzi = v)),
                      _buildAmenityChip('Balcón Panorámico', Icons.balcony, _requireBalcony, (v) => setState(() => _requireBalcony = v)),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Barra Inferior de Acción
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _apply,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  label: Text(
                    'Aplicar Filtros',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricePreset(String label, double min, double max) {
    final isSelected = (_minPrice - min).abs() < 1000 && (_maxPrice - max).abs() < 1000;
    return InkWell(
      onTap: () => setState(() {
        _minPrice = min;
        _maxPrice = max;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.primaryDark,
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppTheme.primaryBlue,
      backgroundColor: const Color(0xFFF8FAFC),
      labelStyle: GoogleFonts.poppins(
        color: isSelected ? Colors.white : AppTheme.primaryDark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildCapacityCard(int capacity, String label, IconData icon) {
    final isSelected = _minCapacity == capacity;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _minCapacity = capacity),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppTheme.primaryBlue : const Color(0xFF64748B), size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppTheme.primaryBlue : const Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmenityChip(String label, IconData icon, bool isChecked, ValueChanged<bool> onChanged) {
    return FilterChip(
      avatar: Icon(icon, size: 16, color: isChecked ? Colors.white : AppTheme.primaryBlue),
      label: Text(label),
      selected: isChecked,
      onSelected: (v) => onChanged(v),
      selectedColor: AppTheme.primaryBlue,
      backgroundColor: const Color(0xFFF8FAFC),
      labelStyle: GoogleFonts.poppins(
        color: isChecked ? Colors.white : AppTheme.primaryDark,
        fontWeight: isChecked ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isChecked ? AppTheme.primaryBlue : const Color(0xFFE2E8F0)),
      ),
    );
  }
}
