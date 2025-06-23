import 'package:schoollms/models/user.dart';

class Admin extends User {
  Admin(
      {required String id,
      required String country,
      required String citizenshipId,
      required String name,
      required String surname,
      String email = '',
      String contactNumber = ''})
      : super(
            id: id,
            country: country,
            citizenshipId: citizenshipId,
            name: name,
            surname: surname,
            email: email,
            contactNumber: contactNumber);
}
