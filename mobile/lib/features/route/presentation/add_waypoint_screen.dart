import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/route/data/route_repository.dart';
import 'package:sayurpintar/features/route/providers/route_provider.dart';
import 'package:sayurpintar/shared/widgets/sp_button.dart';
import 'package:sayurpintar/shared/widgets/sp_input.dart';
import 'package:sayurpintar/shared/widgets/sp_loading.dart';

class AddWaypointScreen extends ConsumerStatefulWidget {
  final String? waypointId;
  final double? initialLat;
  final double? initialLng;

  const AddWaypointScreen({
    super.key,
    this.waypointId,
    this.initialLat,
    this.initialLng,
  });

  @override
  ConsumerState<AddWaypointScreen> createState() => _AddWaypointScreenState();
}

class _AddWaypointScreenState extends ConsumerState<AddWaypointScreen> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng _selectedLocation = const LatLng(-6.2088, 106.8456);
  int _priority = 1;
  TimeOfDay? _preferredStart;
  TimeOfDay? _preferredEnd;
  bool _isLoading = false;
  bool _isEditing = false;
  Waypoint? _existingWaypoint;
  bool _mapReady = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);
    }
    if (widget.waypointId != null) {
      _isEditing = true;
      _loadExistingWaypoint();
    }
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingWaypoint() async {
    // Load from provider/cache
    final waypoints = await ref.read(waypointsProvider.future);
    final existing = waypoints.where((w) => w.id == widget.waypointId).toList();
    if (existing.isNotEmpty && mounted) {
      final wp = existing.first;
      setState(() {
        _existingWaypoint = wp;
        _labelController.text = wp.label;
        _addressController.text = wp.address ?? '';
        _notesController.text = wp.notes ?? '';
        _priority = wp.priority;
        _selectedLocation = LatLng(wp.latitude, wp.longitude);

        if (wp.preferredTimeStart != null) {
          final parts = wp.preferredTimeStart!.split(':');
          _preferredStart = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
        if (wp.preferredTimeEnd != null) {
          final parts = wp.preferredTimeEnd!.split(':');
          _preferredEnd = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      });
      _mapController.move(_selectedLocation, 16);
    }
  }

  Future<void> _getCurrentLocation() async {
    if (widget.initialLat != null) return; // Don't override initial location

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted && !_isEditing) {
        final loc = LatLng(position.latitude, position.longitude);
        setState(() => _selectedLocation = loc);
        _mapController.move(loc, 16);
      }
    } catch (_) {
      // Use default
    }
  }

  void _onMapTap(TapPosition position, LatLng point) {
    setState(() => _selectedLocation = point);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_preferredStart ?? const TimeOfDay(hour: 6, minute: 0))
          : (_preferredEnd ?? const TimeOfDay(hour: 12, minute: 0)),
      helpText: isStart ? 'Waktu Mulai' : 'Waktu Selesai',
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _preferredStart = picked;
        } else {
          _preferredEnd = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    return '${tod.hour.toString().padLeft(2, '0')}:'
        '${tod.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(routeRepositoryProvider);

      if (_isEditing && _existingWaypoint != null) {
        await repo.updateWaypoint(
          _existingWaypoint!.id,
          UpdateWaypointRequest(
            label: _labelController.text.trim(),
            address: _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : null,
            latitude: _selectedLocation.latitude,
            longitude: _selectedLocation.longitude,
            priority: _priority,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
            preferredTimeStart: _preferredStart != null
                ? _formatTimeOfDay(_preferredStart!)
                : null,
            preferredTimeEnd:
                _preferredEnd != null ? _formatTimeOfDay(_preferredEnd!) : null,
          ),
        );
      } else {
        await repo.addWaypoint(
          AddWaypointRequest(
            label: _labelController.text.trim(),
            address: _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : null,
            latitude: _selectedLocation.latitude,
            longitude: _selectedLocation.longitude,
            priority: _priority,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
            preferredTimeStart: _preferredStart != null
                ? _formatTimeOfDay(_preferredStart!)
                : null,
            preferredTimeEnd:
                _preferredEnd != null ? _formatTimeOfDay(_preferredEnd!) : null,
          ),
        );
      }

      ref.invalidate(waypointsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Titik berhasil diperbarui'
                  : 'Titik berhasil ditambahkan',
            ),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMapPicker() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _selectedLocation,
              zoom: 15,
              onTap: _onMapTap,
              onMapReady: () => _mapReady = true,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sayurpintar.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 40,
                    height: 50,
                    child: const Icon(
                      Icons.location_on,
                      color: AppTheme.primaryGreen,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Location button
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              children: [
                _SmallMapButton(
                  icon: Icons.my_location,
                  onPressed: () async {
                    try {
                      final position = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high,
                      );
                      final loc = LatLng(
                        position.latitude,
                        position.longitude,
                      );
                      setState(() => _selectedLocation = loc);
                      _mapController.move(loc, 16);
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 8),
                _SmallMapButton(
                  icon: Icons.add,
                  onPressed: () {
                    _mapController.move(
                      _mapController.center,
                      _mapController.zoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 8),
                _SmallMapButton(
                  icon: Icons.remove,
                  onPressed: () {
                    _mapController.move(
                      _mapController.center,
                      _mapController.zoom - 1,
                    );
                  },
                ),
              ],
            ),
          ),

          // Coordinates display
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Text(
                '${_selectedLocation.latitude.toStringAsFixed(5)}, '
                '${_selectedLocation.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prioritas',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Row(
          children: List.generate(3, (i) {
            final starValue = i + 1;
            final isSelected = _priority == starValue;
            return GestureDetector(
              onTap: () => setState(() => _priority = starValue),
              child: Container(
                margin: const EdgeInsets.only(right: AppTheme.space8),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space16,
                  vertical: AppTheme.space8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryGreen.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color:
                        isSelected ? AppTheme.primaryGreen : AppTheme.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(starValue, (_) {
                    return const Icon(
                      Icons.star,
                      size: 16,
                      color: AppTheme.accent,
                    );
                  }),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTimePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Waktu Kunjungan (Opsional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.space8),
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                label: 'Mulai',
                time: _preferredStart,
                onTap: () => _pickTime(isStart: true),
                onClear: _preferredStart != null
                    ? () => setState(() => _preferredStart = null)
                    : null,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.space8),
              child: Icon(Icons.arrow_forward, color: AppTheme.textSecondary),
            ),
            Expanded(
              child: _TimeButton(
                label: 'Selesai',
                time: _preferredEnd,
                onTap: () => _pickTime(isStart: false),
                onClear: _preferredEnd != null
                    ? () => setState(() => _preferredEnd = null)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Titik' : 'Tambah Titik'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Titik?'),
                    content: const Text(
                      'Titik ini akan dihapus secara permanen.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            final repo = ref.read(routeRepositoryProvider);
                            await repo.deleteWaypoint(_existingWaypoint!.id);
                            ref.invalidate(waypointsProvider);
                            if (mounted) context.pop();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Gagal menghapus: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                        ),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const SPLoading(message: 'Menyimpan...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.space24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Map picker
                    const Text(
                      'Pilih Lokasi',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.space8),
                    _buildMapPicker(),
                    const SizedBox(height: AppTheme.space24),

                    // Label
                    SPInput(
                      label: 'Nama Titik',
                      hint: 'Contoh: Rumah Pak Budi',
                      controller: _labelController,
                      prefixIcon: Icons.label,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Nama wajib diisi';
                        }
                        if (v.trim().length < 2) {
                          return 'Nama minimal 2 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.space20),

                    // Address
                    SPInput(
                      label: 'Alamat',
                      hint: 'Jl. Contoh No. 123, Kelurahan...',
                      controller: _addressController,
                      prefixIcon: Icons.location_on,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: AppTheme.space20),

                    // Priority
                    _buildPrioritySelector(),
                    const SizedBox(height: AppTheme.space20),

                    // Notes
                    SPInput(
                      label: 'Catatan (Opsional)',
                      hint: 'Misal: Langganan setiap Selasa',
                      controller: _notesController,
                      prefixIcon: Icons.note_alt_outlined,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: AppTheme.space20),

                    // Time picker
                    _buildTimePicker(),
                    const SizedBox(height: AppTheme.space32),

                    // Save button
                    SPButton(
                      label: _isEditing ? 'Perbarui Titik' : 'Simpan Titik',
                      onPressed: _save,
                      icon: Icons.save,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: AppTheme.space16),
                  ],
                ),
              ),
            ),
    );
  }
}

// ──────────────────────────────────────────────
// Helper widgets
// ──────────────────────────────────────────────

class _SmallMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _SmallMapButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      shape: const CircleBorder(),
      color: Colors.white,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _TimeButton({
    required this.label,
    required this.time,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.space16,
          vertical: AppTheme.space12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: time != null ? AppTheme.primaryGreen : AppTheme.divider,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time,
              size: 18,
              color:
                  time != null ? AppTheme.primaryGreen : AppTheme.textSecondary,
            ),
            const SizedBox(width: AppTheme.space8),
            Text(
              time != null
                  ? '${time!.hour.toString().padLeft(2, '0')}:'
                      '${time!.minute.toString().padLeft(2, '0')}'
                  : label,
              style: TextStyle(
                color: time != null
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
