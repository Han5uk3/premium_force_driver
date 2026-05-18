import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:premium_force_driver/common_widgets/premiumloader.dart';
import 'package:premium_force_driver/common_widgets/textfield.dart';
import 'package:premium_force_driver/common_widgets/snackbar.dart';
import 'package:premium_force_driver/l10n/app_localizations.dart';
import 'package:premium_force_driver/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ManageProfilePage extends StatefulWidget {
  const ManageProfilePage({super.key});

  @override
  State<ManageProfilePage> createState() => _ManageProfilePageState();
}

class _ManageProfilePageState extends State<ManageProfilePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _licenseController = TextEditingController();

  File? _profileImage;
  double? latitude;
  double? longitude;
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  Future<void> _uploadProfileImage(File file) async {
    setState(() {
      _isLoading = true;
    });

    final success = await Provider.of<AuthProvider>(context, listen: false)
        .updateProfileImage(file);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (success) {
      AnimatedSnackBar.show(
        context,
        AppLocalizations.of(context)!.profileUpdatedSuccessfully,
        'S',
      );
    } else {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      AnimatedSnackBar.show(
        context,
        authProvider.errorMessage ?? 'Failed to update profile image',
        'E',
      );
    }
  }

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
    );
    _animController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _populateFieldsFromUser();
  }

  void _populateFieldsFromUser() {
    final user = Provider.of<AuthProvider>(context).driver;
    if (user != null && _nameController.text.isEmpty) {
      // Only populate once fields are empty
      _nameController.text = user.fullName;
      _emailController.text = user.email;
      _phoneController.text = '${user.countryCode} ${user.phoneNumber}';
      _licenseController.text = user.licenseNumber ?? '';
      _locationController.text = user.location ?? '';
      latitude = user.lat;
      longitude = user.long;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3E230A), Color(0xFF141313)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    loc.chooseProfilePicture,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImageSourceOption(
                        icon: Icons.camera_alt_rounded,
                        label: loc.camera,
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.camera,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            final file = File(image.path);
                            setState(() {
                              _profileImage = file;
                            });
                            _uploadProfileImage(file);
                          }
                        },
                      ),
                      _buildImageSourceOption(
                        icon: Icons.photo_library_rounded,
                        label: loc.gallery,
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            final file = File(image.path);
                            setState(() {
                              _profileImage = file;
                            });
                            _uploadProfileImage(file);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF404040),
                  Color(0xFFC0C0C0),
                  Color(0xFF808080),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0A08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: const Color(0xFFC0C0C0), size: 30),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Future<void> _handleUpdateProfile() async {
  //   if (!_formKey.currentState!.validate()) return;

  //   final user = Provider.of<AuthProvider>(context, listen: false).driver;
  //   if (user == null) return;

  //   setState(() => _isLoading = true);

  //   final nameParts = _nameController.text.trim().split(' ');
  //   final firstName = nameParts.first;
  //   final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

  //   final success = await Provider.of<AuthProvider>(context, listen: false)
  //       .updateDriverProfile(
  //         firstName: firstName,
  //         lastName: lastName,
  //         email: _emailController.text.trim(),
  //         location: _locationController.text.trim(),
  //         lat:_latitude,
  //         long: longitude,
  //         profileImage: _profileImage,
  //       );

  //   if (!mounted) return;
  //   setState(() => _isLoading = false);

  //   if (success) {
  //     AnimatedSnackBar.show(
  //       context,
  //       AppLocalizations.of(context)!.profileUpdatedSuccessfully,
  //       'S',
  //     );

  //     if (!mounted) return;
  //     Navigator.pop(context);
  //   } else {
  //     final authProvider = Provider.of<AuthProvider>(context, listen: false);
  //     AnimatedSnackBar.show(
  //       context,
  //       authProvider.errorMessage ?? 'Update failed',
  //       'E',
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).driver;

    // If user data is missing, try to fetch it
    if (user == null && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<AuthProvider>(context, listen: false).fetchDriver();
        }
      });
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF303030),
            Color(0xFF303030),
            Color(0xFF1A1A1A),
            Color(0xFF1A1A1A),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isLoading,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),

                        // Profile Picture
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              children: [
                                // Gradient border
                                Container(
                                  width: 116,
                                  height: 116,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF404040),
                                        Color(0xFFC0C0C0),
                                        Color(0xFF808080),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 112,
                                      height: 112,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF0D0A08),
                                      ),
                                      child: _profileImage != null
                                          ? ClipOval(
                                              child: Image.file(
                                                _profileImage!,
                                                width: 112,
                                                height: 112,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : (user?.profileImageUrl != null &&
                                                user!
                                                    .profileImageUrl!
                                                    .isNotEmpty)
                                          ? ClipOval(
                                              child: CachedNetworkImage(
                                                imageUrl: user.profileImageUrl!,
                                                width: 112,
                                                height: 112,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    Center(
                                                      child: SizedBox(
                                                        width: 24,
                                                        height: 32,
                                                        child: PremiumLoader(
                                                          color: Colors.white
                                                              .withAlpha(150),
                                                        ),
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        _buildPlaceholderIcon(),
                                              ),
                                            )
                                          : _buildPlaceholderIcon(),
                                    ),
                                  ),
                                ),
                                // Camera edit icon
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF404040),
                                          Color(0xFFC0C0C0),
                                          Color(0xFF808080),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(100),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Center(
                          child: Text(
                            AppLocalizations.of(context)!.tapToAddPhoto,
                            style: TextStyle(
                              color: Colors.white.withAlpha(100),
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Name field
                        PremiumTextField(
                          readOnly: true,
                          title: AppLocalizations.of(context)!.fullName,
                          controller: _nameController,
                          hintText: AppLocalizations.of(
                            context,
                          )!.enterYourFullName,
                          fontsize: 13,
                          keyboardType: TextInputType.name,
                          needTitle: true,
                          obscureText: false,
                          prefixIcon: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return const LinearGradient(
                                colors: [
                                  Color(0xFF404040),
                                  Color(0xFFC0C0C0),
                                  Color(0xFF808080),
                                ],
                              ).createShader(bounds);
                            },
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(
                                context,
                              )!.pleaseEnterYourName;
                            }
                            if (value.length < 2) {
                              return AppLocalizations.of(
                                context,
                              )!.nameMustBeAtLeast2Characters;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Phone number (display only)
                        PremiumTextField(
                          title: AppLocalizations.of(context)!.phoneNumber,
                          controller: _phoneController,
                          hintText: "",
                          fontsize: 13,
                          needTitle: true,
                          obscureText: false,
                          enabled: false,
                          readOnly: true,
                          prefixIcon: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return const LinearGradient(
                                colors: [
                                  Color(0xFF404040),
                                  Color(0xFFC0C0C0),
                                  Color(0xFF808080),
                                ],
                              ).createShader(bounds);
                            },
                            child: const Icon(
                              Icons.phone_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // License number (display only)
                        PremiumTextField(
                          title: AppLocalizations.of(context)!.licenseNumber,
                          controller: _licenseController,
                          hintText: "",
                          fontsize: 13,
                          needTitle: true,
                          obscureText: false,
                          enabled: false,
                          readOnly: true,
                          prefixIcon: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return const LinearGradient(
                                colors: [
                                  Color(0xFF404040),
                                  Color(0xFFC0C0C0),
                                  Color(0xFF808080),
                                ],
                              ).createShader(bounds);
                            },
                            child: const Icon(
                              Icons.badge_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Email field
                        // PremiumTextField(
                        //   title: AppLocalizations.of(context)!.emailAddress,
                        //   controller: _emailController,
                        //   hintText: AppLocalizations.of(
                        //     context,
                        //   )!.enterYourEmailAddress,
                        //   fontsize: 13,
                        //   keyboardType: TextInputType.emailAddress,
                        //   needTitle: true,
                        //   obscureText: false,
                        //   enabled: false,
                        //   readOnly: true,
                        //   prefixIcon: ShaderMask(
                        //     shaderCallback: (Rect bounds) {
                        //       return const LinearGradient(
                        //         colors: [
                        //           Color(0xFF404040),
                        //           Color(0xFFC0C0C0),
                        //           Color(0xFF808080),
                        //         ],
                        //       ).createShader(bounds);
                        //     },
                        //     child: const Icon(
                        //       Icons.email_outlined,
                        //       color: Colors.white,
                        //       size: 20,
                        //     ),
                        //   ),
                        // ),
                        const SizedBox(height: 20),

                        // Location field (tap to open location picker)
                        // _buildLocationField(),
                        // const SizedBox(height: 20),
                        const SizedBox(height: 36),

                        // Save Changes button
                        // PremiumButton(
                        //   showLoader: _isLoading,
                        //   fontsize: 16,
                        //   text: "Save Changes",
                        //   onTap: _isLoading ? () {} : _handleUpdateProfile,
                        // ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Loading overlay
            if (_isLoading) const PremiumLoaderOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Center(
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            colors: [Color(0xFF404040), Color(0xFFC0C0C0), Color(0xFF808080)],
          ).createShader(bounds);
        },
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 48),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(150), Colors.transparent],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          title: Text(
            AppLocalizations.of(context)!.manageProfile,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}
