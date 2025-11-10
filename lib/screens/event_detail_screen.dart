import 'package:flutter/material.dart';

import '../models/event.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'user_selection_screen.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _apiService = ApiService();
  Event? _event;
  bool _isLoading = true;
  bool _isRegistered = false;
  String? _userId;
  String? _userRole;
  List<User> _registeredUsers = [];
  bool _showUsers = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userId = await AuthService.getUserId();
    final role = await AuthService.getUserRole();
    setState(() {
      _userId = userId;
      _userRole = role;
    });
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);
    try {
      final event = await _apiService.getEvent(widget.eventId);

      // Cargar usuarios registrados para obtener el conteo real
      List<User> registeredUsersList = [];
      try {
        registeredUsersList = await _apiService.getEventUsers(widget.eventId);
      } catch (e) {
        // Si falla, usar la lista del evento
        registeredUsersList = [];
      }

      // Actualizar el evento con el conteo real de usuarios
      final updatedEvent = Event(
        id: event.id,
        title: event.title,
        description: event.description,
        createdBy: event.createdBy,
        createdAt: event.createdAt,
        updatedAt: event.updatedAt,
        registeredUsers: registeredUsersList.map((u) => u.id).toList(),
        checkIns: event.checkIns,
      );

      setState(() {
        _event = updatedEvent;
        _registeredUsers = registeredUsersList;
        _isRegistered = registeredUsersList.any((u) => u.id == _userId);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
      }
    }
  }

  Future<void> _toggleRegistration() async {
    try {
      if (_isRegistered) {
        await _apiService.unregisterFromEvent(widget.eventId);
        setState(() => _isRegistered = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Te has desinscrito del evento')),
          );
        }
      } else {
        await _apiService.registerToEvent(widget.eventId);
        setState(() => _isRegistered = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Te has inscrito al evento')),
          );
        }
      }
      _loadEvent();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
      }
    }
  }

  Future<void> _loadRegisteredUsers() async {
    if (_showUsers) {
      setState(() => _showUsers = false);
      return;
    }

    try {
      final users = await _apiService.getEventUsers(widget.eventId);
      setState(() {
        _registeredUsers = users;
        _showUsers = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
      }
    }
  }

  Future<void> _toggleCheckIn(String userId) async {
    try {
      await _apiService.toggleCheckIn(widget.eventId, userId);
      _loadEvent();
      if (_showUsers) {
        _loadRegisteredUsers();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Check-in actualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
      }
    }
  }

  bool _canManageEvent() {
    return _userRole == 'admin' || _userRole == 'eventManager';
  }

  bool _canSelfRegister() {
    // Solo usuarios regulares pueden auto-inscribirse
    return _userRole == 'user';
  }

  Future<void> _unregisterUser(String userId) async {
    // Buscar el usuario en la lista para mostrar su nombre
    final user = _registeredUsers.firstWhere(
      (u) => u.id == userId,
      orElse: () => User(
        id: userId,
        email: '',
        name: 'Usuario',
        role: 'user',
        isActive: true,
      ),
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desinscribir Usuario'),
        content: Text(
          '¿Estás seguro de que deseas desinscribir a ${user.name} del evento?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Desinscribir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _apiService.unregisterUserFromEvent(widget.eventId, userId);
      _loadEvent();
      if (_showUsers) {
        _loadRegisteredUsers();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.name} ha sido desinscrito del evento'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
      }
    }
  }

  Future<void> _showRegisterUserDialog() async {
    if (_event == null) return;

    final selectedUser = await Navigator.push<User>(
      context,
      MaterialPageRoute(
        builder: (context) => UserSelectionScreen(
          excludedUserIds: _event!.registeredUsers,
          eventId: widget.eventId,
        ),
      ),
    );

    if (selectedUser != null && mounted) {
      try {
        await _apiService.registerUserToEvent(widget.eventId, selectedUser.id);
        _loadEvent();
        if (_showUsers) {
          _loadRegisteredUsers();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${selectedUser.name} ha sido inscrito al evento'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiService.getErrorMessage(e))),
          );
        }
      }
    }
  }

  bool _isCheckedIn() {
    if (_userId == null || _event == null) return false;
    // Verificar check-in desde el campo attended del usuario o desde checkIns del evento
    final user = _registeredUsers.firstWhere(
      (u) => u.id == _userId,
      orElse: () =>
          User(id: _userId!, email: '', name: '', role: 'user', isActive: true),
    );
    return user.attended == true || _event!.checkIns[_userId] == true;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Evento'), elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Evento'), elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Evento no encontrado',
                style: TextStyle(color: Colors.grey[600], fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    final isCheckedIn = _isCheckedIn();

    return Scaffold(
      appBar: AppBar(title: Text(_event!.title), elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Header con gradiente
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${_event!.registeredUsers.length} registrados',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _event!.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _event!.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            // Contenido principal
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Indicador de check-in para usuarios regulares
                  if (_canSelfRegister() && _isRegistered) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isCheckedIn
                              ? [Colors.green.shade50, Colors.green.shade100]
                              : [Colors.orange.shade50, Colors.orange.shade100],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCheckedIn
                              ? Colors.green.shade300
                              : Colors.orange.shade300,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isCheckedIn
                                  ? Colors.green.shade400
                                  : Colors.orange.shade400,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCheckedIn
                                  ? Icons.check_circle
                                  : Icons.pending_actions,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCheckedIn
                                      ? 'Check-in Realizado'
                                      : 'Check-in Pendiente',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isCheckedIn
                                        ? Colors.green.shade900
                                        : Colors.orange.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isCheckedIn
                                      ? 'Ya has realizado tu check-in en este evento'
                                      : 'Aún no has realizado tu check-in',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isCheckedIn
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Botón de auto-inscripción para usuarios regulares
                  if (_canSelfRegister()) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _toggleRegistration,
                        icon: Icon(
                          _isRegistered ? Icons.cancel : Icons.check_circle,
                          size: 24,
                        ),
                        label: Text(
                          _isRegistered ? 'Desinscribirse' : 'Inscribirse',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRegistered
                              ? Colors.red.shade400
                              : Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Admin y eventManager siempre pueden ver usuarios registrados
                  if (_canManageEvent()) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loadRegisteredUsers,
                            icon: Icon(
                              _showUsers
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                            label: Text(
                              _showUsers
                                  ? 'Ocultar Usuarios'
                                  : 'Ver Usuarios Registrados',
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showRegisterUserDialog,
                            icon: const Icon(Icons.person_add, size: 20),
                            label: const Text(
                              'Inscribir Usuario',
                              style: TextStyle(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_showUsers && _canManageEvent()) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Usuarios Registrados',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._registeredUsers.map((user) {
                            // Verificar check-in desde el campo attended del usuario o desde checkIns del evento
                            final userCheckedIn =
                                user.attended == true ||
                                _event!.checkIns[user.id] == true;
                            final isCurrentUser = user.id == _userId;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: userCheckedIn
                                      ? Colors.green.shade200
                                      : Colors.grey.shade200,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: userCheckedIn
                                                  ? [
                                                      Colors.green.shade400,
                                                      Colors.green.shade600,
                                                    ]
                                                  : [
                                                      Colors.grey.shade300,
                                                      Colors.grey.shade400,
                                                    ],
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              user.name[0].toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      user.name,
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isCurrentUser)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'Tú',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                user.email,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: userCheckedIn
                                                      ? Colors.green.shade50
                                                      : Colors.orange.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      userCheckedIn
                                                          ? Icons.check_circle
                                                          : Icons
                                                                .pending_actions,
                                                      size: 16,
                                                      color: userCheckedIn
                                                          ? Colors
                                                                .green
                                                                .shade700
                                                          : Colors
                                                                .orange
                                                                .shade700,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      userCheckedIn
                                                          ? 'Check-in realizado'
                                                          : 'Check-in pendiente',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: userCheckedIn
                                                            ? Colors
                                                                  .green
                                                                  .shade700
                                                            : Colors
                                                                  .orange
                                                                  .shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Botones de acción
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Botón de Check-in
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () =>
                                                _toggleCheckIn(user.id),
                                            icon: Icon(
                                              userCheckedIn
                                                  ? Icons.check_circle
                                                  : Icons
                                                        .radio_button_unchecked,
                                              size: 18,
                                            ),
                                            label: Text(
                                              userCheckedIn
                                                  ? 'Check-in ✓'
                                                  : 'Hacer Check-in',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: userCheckedIn
                                                  ? Colors.green.shade500
                                                  : Colors.blue.shade500,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        // Botón para desinscribir (solo si no es el usuario actual)
                                        if (_canManageEvent() &&
                                            !isCurrentUser) ...[
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _unregisterUser(user.id),
                                              icon: const Icon(
                                                Icons.person_remove,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                'Desinscribir',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.red.shade500,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
