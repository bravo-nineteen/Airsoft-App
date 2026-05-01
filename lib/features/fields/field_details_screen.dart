import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/localization/app_localizations.dart';
import '../../shared/widgets/persistent_shell_bottom_nav.dart';

import 'field_booking_inbox_screen.dart';
import 'field_model.dart';
import 'field_repository.dart';

class FieldDetailsScreen extends StatefulWidget {
  const FieldDetailsScreen({super.key, required this.field});

  final FieldModel field;

  @override
  State<FieldDetailsScreen> createState() => _FieldDetailsScreenState();
}

class _FieldDetailsScreenState extends State<FieldDetailsScreen> {
  final FieldRepository _repository = FieldRepository();
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _claimStaffNameController =
      TextEditingController();
  final TextEditingController _claimIdController = TextEditingController();
  final TextEditingController _claimPhoneController = TextEditingController();
  final TextEditingController _claimEmailController = TextEditingController();
  final TextEditingController _claimNoteController =
      TextEditingController();
  final TextEditingController _bookingNameController = TextEditingController();
  final TextEditingController _bookingPhoneController = TextEditingController();
  final TextEditingController _bookingEmailController = TextEditingController();
  final TextEditingController _bookingMessageController =
      TextEditingController();

  List<FieldReviewModel> _reviews = <FieldReviewModel>[];
  List<FieldBookingOptionModel> _bookingOptions = <FieldBookingOptionModel>[];
  List<String> _photos = <String>[];
  final Set<String> _selectedBookingOptionIds = <String>{};
  bool _loadingReviews = true;
  bool _loadingBookingOptions = true;
  bool _savingReview = false;
  bool _submittingClaim = false;
  bool _submittingBooking = false;
  int _selectedRating = 5;
  String? _editingReviewId;

  FieldModel get field => widget.field;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  bool get _isFieldManager {
    return field.claimStatus == 'verified' &&
        (field.claimedByUserId ?? '') == (_currentUserId ?? '');
  }

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _loadBookingOptions();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final urls = await _repository.getFieldPhotos(field.id);
      // Prepend the main image_url if not already in the list.
      final main = (field.imageUrl ?? '').trim();
      final all = <String>{
        if (main.isNotEmpty) main,
        ...urls,
      }.toList();
      if (mounted) setState(() => _photos = all);
    } catch (_) {
      // Non-fatal — gallery just won't show.
    }
  }

  Future<void> _loadBookingOptions() async {
    setState(() {
      _loadingBookingOptions = true;
    });

    try {
      final List<FieldBookingOptionModel> options = await _repository
          .getBookingOptions(field.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _bookingOptions = options;
        _loadingBookingOptions = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingBookingOptions = false;
      });
    }
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loadingReviews = true;
    });

    try {
      final List<FieldReviewModel> loaded = await _repository.getFieldReviews(
        field.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _reviews = loaded;
        _loadingReviews = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingReviews = false;
      });
    }
  }

  Future<void> _submitReview() async {
    final String text = _reviewController.text.trim();
    if (text.isEmpty || _savingReview) {
      return;
    }

    setState(() {
      _savingReview = true;
    });

    try {
      if (_editingReviewId != null) {
        await _repository.updateFieldReview(
          reviewId: _editingReviewId!,
          rating: _selectedRating,
          reviewText: text,
        );
      } else {
        await _repository.upsertFieldReview(
          fieldId: field.id,
          rating: _selectedRating,
          reviewText: text,
        );
      }

      _reviewController.clear();
      _editingReviewId = null;
      await _loadReviews();
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('reviewPosted'))));
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(l10n.t('failedPostReview', args: {'error': '$error'})),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingReview = false;
        });
      }
    }
  }

  void _startEditingReview(FieldReviewModel review) {
    setState(() {
      _editingReviewId = review.id;
      _selectedRating = review.rating;
      _reviewController.text = review.reviewText;
    });
  }

  void _cancelEditingReview() {
    setState(() {
      _editingReviewId = null;
      _reviewController.clear();
      _selectedRating = 5;
    });
  }

  Future<void> _deleteReview(FieldReviewModel review) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete review?'),
          content: const Text('This will permanently remove your review.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _repository.deleteFieldReview(review.id);
      if (_editingReviewId == review.id) {
        _cancelEditingReview();
      }
      await _loadReviews();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Review deleted')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete review: $error')));
    }
  }

  Future<bool> _submitClaimRequest() async {
    if (_submittingClaim) {
      return false;
    }
    final String staffName = _claimStaffNameController.text.trim();
    final String idNumber = _claimIdController.text.trim();
    final String phone = _claimPhoneController.text.trim();
    final String email = _claimEmailController.text.trim();
    if (staffName.isEmpty || idNumber.isEmpty || phone.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in all claim verification fields.')),
      );
      return false;
    }

    setState(() {
      _submittingClaim = true;
    });

    try {
      await _repository.submitFieldClaimRequest(
        fieldId: field.id,
        staffName: staffName,
        officialIdNumber: idNumber,
        officialPhone: phone,
        officialEmail: email,
        verificationNote: _claimNoteController.text,
      );
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Claim request sent. Admin will review your request first. If approved, they will send a Google Play payment request (¥5000/year).',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed claim request: $error')));
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _submittingClaim = false;
        });
      }
    }
  }

  Future<void> _openClaimFieldDialog() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Claim field'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Submit your field staff verification details. Payment is requested only after admin approval.',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _claimStaffNameController,
                  decoration: const InputDecoration(labelText: 'Staff name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _claimIdController,
                  decoration: const InputDecoration(
                    labelText: 'Official ID / employee ID',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _claimPhoneController,
                  decoration: const InputDecoration(labelText: 'Official phone'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _claimEmailController,
                  decoration: const InputDecoration(labelText: 'Official email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _claimNoteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Message to admin (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _submittingClaim
                  ? null
                  : () async {
                      final bool success = await _submitClaimRequest();
                      if (!dialogContext.mounted || !success) {
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                    },
              child: _submittingClaim
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit claim'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitBookingRequest() async {
    if (_submittingBooking) {
      return;
    }

    final String name = _bookingNameController.text.trim();
    final String phone = _bookingPhoneController.text.trim();
    final String email = _bookingEmailController.text.trim();
    final String message = _bookingMessageController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill name, phone, email, and message.')),
      );
      return;
    }

    final List<FieldBookingOptionModel> selectedOptions = _bookingOptions
        .where((FieldBookingOptionModel option) {
          return _selectedBookingOptionIds.contains(option.id);
        })
        .toList();

    setState(() {
      _submittingBooking = true;
    });

    try {
      await _repository.createBookingRequest(
        fieldId: field.id,
        bookingName: name,
        bookingPhone: phone,
        bookingEmail: email,
        message: message,
        selectedOptions: selectedOptions,
      );
      if (!mounted) {
        return;
      }
      _bookingMessageController.clear();
      setState(() {
        _selectedBookingOptionIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking request sent to field staff.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed booking request: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _submittingBooking = false;
        });
      }
    }
  }

  Future<void> _showAddBookingOptionDialog() async {
    final TextEditingController labelController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    String selectedType = 'other';

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setModalState) {
            return AlertDialog(
              title: const Text('Add booking option'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'pickup', child: Text('Pick up')),
                      DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (String? value) {
                      setModalState(() {
                        selectedType = value ?? 'other';
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Type'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: labelController,
                    decoration: const InputDecoration(labelText: 'Label'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (optional, JPY)',
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    final String label = labelController.text.trim();
    final int? price = int.tryParse(priceController.text.trim());
    if (label.isEmpty) {
      return;
    }

    try {
      await _repository.addBookingOption(
        fieldId: field.id,
        optionType: selectedType,
        label: label,
        priceYen: price,
      );
      await _loadBookingOptions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add option: $error')));
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _claimStaffNameController.dispose();
    _claimIdController.dispose();
    _claimPhoneController.dispose();
    _claimEmailController.dispose();
    _claimNoteController.dispose();
    _bookingNameController.dispose();
    _bookingPhoneController.dispose();
    _bookingEmailController.dispose();
    _bookingMessageController.dispose();
    super.dispose();
  }

  Future<void> _openInMaps(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final String label = widget.field.name.trim().isEmpty
        ? l10n.t('fieldFallbackName')
        : widget.field.name;
    final String locationQuery = widget.field.fullLocation.trim().isNotEmpty
        ? '${widget.field.fullLocation} ($label)'
        : label;

    final Uri primaryGeo = Uri.parse(
      'geo:${widget.field.latitude},${widget.field.longitude}?q=${Uri.encodeComponent(locationQuery)}',
    );
    final Uri fallbackGoogle = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${widget.field.latitude},${widget.field.longitude}',
    );
    final Uri fallbackApple = Uri.parse(
      'https://maps.apple.com/?ll=${widget.field.latitude},${widget.field.longitude}&q=${Uri.encodeComponent(locationQuery)}',
    );

    final bool openedGeo = await launchUrl(
      primaryGeo,
      mode: LaunchMode.externalApplication,
    );
    if (openedGeo) {
      return;
    }

    final bool openedGoogle = await launchUrl(
      fallbackGoogle,
      mode: LaunchMode.externalApplication,
    );
    if (openedGoogle) {
      return;
    }

    final bool openedApple = await launchUrl(
      fallbackApple,
      mode: LaunchMode.externalApplication,
    );

    if (!openedApple && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.t('failedOpenMapApp'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final List<String> features = field.features;
    final List<String> pros = field.pros;
    final List<String> cons = field.cons;
    final secondaryLine = [
      if ((field.prefecture ?? '').isNotEmpty) field.prefecture,
      if ((field.city ?? '').isNotEmpty) field.city,
      if ((field.fieldType ?? '').isNotEmpty) field.fieldType,
    ].whereType<String>().join(' • ');

    return Scaffold(
      appBar: AppBar(title: Text(field.name)),
      bottomNavigationBar: const PersistentShellBottomNav(selectedIndex: 4),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isTablet = constraints.maxWidth >= 900;

          final imagePanel = ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _photos.isEmpty
                ? AspectRatio(
                    aspectRatio: isTablet ? 4 / 5 : 16 / 9,
                    child: (field.imageUrl ?? '').isNotEmpty
                        ? Image.network(
                            field.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _FieldImagePlaceholder(name: field.name),
                          )
                        : _FieldImagePlaceholder(name: field.name),
                  )
                : AspectRatio(
                    aspectRatio: isTablet ? 4 / 5 : 16 / 9,
                    child: _FieldPhotoGallery(photos: _photos),
                  ),
          );

          final detailsPanel = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                field.fullLocation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => _openInMaps(context),
                icon: const Icon(Icons.map_outlined),
                label: Text(l10n.t('openInMaps')),
              ),
              if (secondaryLine.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  secondaryLine,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      height: isTablet ? 260 : 220,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(field.latitude, field.longitude),
                          initialZoom: 13.5,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: <Widget>[
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.airsoftonlinejapan.fieldops',
                          ),
                          MarkerLayer(
                            markers: <Marker>[
                              Marker(
                                point: LatLng(field.latitude, field.longitude),
                                width: 56,
                                height: 56,
                                child: Icon(
                                  Icons.location_pin,
                                  size: 42,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.map_outlined, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Map location',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _openInMaps(context),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(l10n.t('openInMaps')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _RatingStars(rating: field.rating ?? 0),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      field.rating != null
                          ? '${field.rating!.toStringAsFixed(1)}${field.reviewCount != null ? ' (${field.reviewCount})' : ''}'
                          : l10n.t('noRatingYet'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    field.description.isEmpty
                        ? l10n.t('noDescriptionAvailable')
                        : field.description,
                  ),
                ),
              ),
              if (features.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BulletSection(
                  title: 'Features',
                  items: features,
                ),
              ],
              if (pros.isNotEmpty || cons.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _BulletSection(
                            title: 'Pros',
                            items: pros,
                            compact: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BulletSection(
                            title: 'Cons',
                            items: cons,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.place),
                  title: Text(field.locationName),
                  subtitle: Text(field.fullLocation),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openInMaps(context),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.pin_drop),
                  title: Text(l10n.t('coordinates')),
                  subtitle: Text('${field.latitude}, ${field.longitude}'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openInMaps(context),
                ),
              ),
              const SizedBox(height: 12),
              _buildClaimCard(),
              const SizedBox(height: 12),
              _buildBookingCard(),
              const SizedBox(height: 12),
              _buildReviewComposer(),
              const SizedBox(height: 8),
              _buildReviewsList(),
            ],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
            child: isTablet
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: imagePanel),
                      const SizedBox(width: 20),
                      Expanded(flex: 6, child: detailsPanel),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      imagePanel,
                      const SizedBox(height: 16),
                      detailsPanel,
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildReviewComposer() {
    final bool isEditing = _editingReviewId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Reviews',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: List<Widget>.generate(5, (int index) {
                final int value = index + 1;
                return IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedRating = value;
                    });
                  },
                  icon: Icon(
                    value <= _selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            TextField(
              controller: _reviewController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Share your experience at this field',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (isEditing)
                  TextButton(
                    onPressed: _savingReview ? null : _cancelEditingReview,
                    child: const Text('Cancel'),
                  ),
                FilledButton.icon(
                  onPressed: _savingReview ? null : _submitReview,
                  icon: _savingReview
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.rate_review_outlined),
                  label: Text(isEditing ? 'Update review' : 'Post review'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimCard() {
    final bool isVerified = field.claimStatus == 'verified';
    final bool isPending = field.claimStatus == 'pending';
    final bool canClaim = !isVerified && !isPending && !_isFieldManager;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Field ownership',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (isVerified)
              const Text('This field is verified and managed by field staff.')
            else if (isPending)
              const Text(
                'A claim request is pending verification. Our team will contact the requester.',
              )
            else
              const Text(
                'Staff can claim this field by submitting official ID, phone, and email. Admin reviews first and sends the ¥5000/year Google Play request only after approval.',
              ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canClaim ? _openClaimFieldDialog : null,
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Claim field'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Message field'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard() {
    if (!field.bookingEnabled && !_isFieldManager) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Bookings are not enabled for this field yet.'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Book this field',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (_isFieldManager)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FieldBookingInboxScreen(field: field),
                        ),
                      );
                    },
                    icon: const Icon(Icons.inbox_outlined),
                    label: const Text('Inbox'),
                  ),
                if (_isFieldManager)
                  TextButton.icon(
                    onPressed: _showAddBookingOptionDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add option'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingBookingOptions)
              const LinearProgressIndicator()
            else if (_bookingOptions.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _bookingOptions.map((FieldBookingOptionModel option) {
                  final bool isSelected = _selectedBookingOptionIds.contains(
                    option.id,
                  );
                  final String label = option.priceYen == null
                      ? option.label
                      : '${option.label} (+¥${option.priceYen})';
                  return FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedBookingOptionIds.add(option.id);
                        } else {
                          _selectedBookingOptionIds.remove(option.id);
                        }
                      });
                    },
                  );
                }).toList(),
              )
            else
              const Text('No pick up/lunch options set yet.'),
            const SizedBox(height: 10),
            TextField(
              controller: _bookingNameController,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bookingPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bookingEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bookingMessageController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Player count, preferred date, requests, etc.',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _submittingBooking ? null : _submitBookingRequest,
              icon: _submittingBooking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_available_outlined),
              label: const Text('Send booking request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_loadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_reviews.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('No reviews yet.'),
        ),
      );
    }

    return Column(
      children: _reviews.map((FieldReviewModel review) {
        final String name = (review.callSign ?? '').trim().isEmpty
            ? 'Operator'
            : review.callSign!;
        final bool isOwner = review.userId == _currentUserId;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage:
                  (review.avatarUrl ?? '').trim().isNotEmpty
                  ? NetworkImage(review.avatarUrl!)
                  : null,
              child: (review.avatarUrl ?? '').trim().isEmpty
                  ? Text(name[0].toUpperCase())
                  : null,
            ),
            title: Row(
              children: <Widget>[
                Expanded(child: Text(name)),
                _RatingStars(rating: review.rating.toDouble()),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(review.reviewText),
            ),
            trailing: isOwner
                ? PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'edit') {
                        _startEditingReview(review);
                      } else if (value == 'delete') {
                        _deleteReview(review);
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({
    required this.title,
    required this.items,
    this.compact = false,
  });

  final String title;
  final List<String> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && compact) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: compact ? EdgeInsets.zero : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('No details provided.')
            else
              ...items.map((String item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('• '),
                      Expanded(child: Text(item)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _FieldPhotoGallery extends StatefulWidget {
  const _FieldPhotoGallery({required this.photos});
  final List<String> photos;

  @override
  State<_FieldPhotoGallery> createState() => _FieldPhotoGalleryState();
}

class _FieldPhotoGalleryState extends State<_FieldPhotoGallery> {
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) => Image.network(
            widget.photos[i],
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image, size: 48),
            ),
          ),
        ),
        if (widget.photos.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.photos.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _page == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _FieldImagePlaceholder extends StatelessWidget {
  const _FieldImagePlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.terrain, size: 56),
          const SizedBox(height: 8),
          Text(name, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final icon = rating >= starValue
            ? Icons.star
            : rating >= starValue - 0.5
            ? Icons.star_half
            : Icons.star_border;

        return Icon(icon, size: 18, color: Colors.amber);
      }),
    );
  }
}
