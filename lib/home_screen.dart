import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String unit = 'Feet'; // Default value is Feet
  String? selectedName; // Holds the currently selected product name
  double? selectedPrice; // Holds the price of the selected product
  double? selectedOffcutPrice; // Holds the offcut price of the selected product
  String? selectedRoll; // Holds the currently selected roll
  String? rollCompatibilityError; // Holds error message for roll compatibility
  bool includeDesign = false;
  bool includeRings = false;
  bool includePockets = false;
  TextEditingController designPriceController = TextEditingController();
  TextEditingController numberOfRingsController = TextEditingController();

  TextEditingController widthController = TextEditingController();
  TextEditingController heightController = TextEditingController();

  // double? ringsprice; //holds price of rings
  // double? pocketsprice; //holds price of pockets

  // Firebase Database reference
  final DatabaseReference _databaseRef =
      FirebaseDatabase.instance.ref(); // Reference to the root of the database
  List<Map<String, dynamic>> databaseArray =
      []; // Array to store full database data
  List<String> productNames = []; // List to hold product names for selection
  List<String> availableRolls =
      []; // List to hold rolls for the selected product

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  /// Fetch all data from the database and store in databaseArray
  void _fetchData() {
    _databaseRef.onValue.listen((DatabaseEvent event) {
      final dataSnapshot = event.snapshot.value;
      if (dataSnapshot != null) {
        final fetchedData = Map<String, dynamic>.from(dataSnapshot as Map);

        // Convert the fetched data to a list of maps
        List<Map<String, dynamic>> dataList = fetchedData.entries
            .map((entry) => {entry.key: entry.value})
            .toList();

        // Extract product names from the database
        final products = dataList
            .where((map) => map.containsKey('Products'))
            .expand((map) => map['Products'] as List<dynamic>)
            .map((product) => product['name'] as String)
            .toList();

        setState(() {
          databaseArray = dataList;
          productNames = products;
        });

        print('Database Array: $databaseArray');
      }
    });
  }

  /// Converts inches to feet
  double convertInchToFeet(double valueInInches) {
    return valueInInches / 12.0; // 12 inches in 1 foot
  }

  /// Converts the input to feet based on the current unit
  double getValueInFeet(String input) {
    if (input.isEmpty) return 0.0;
    double value = double.tryParse(input) ?? 0.0;
    return unit == 'Inch' ? convertInchToFeet(value) : value;
  }

  /// Updates the price, offcut price, and available rolls based on the selected product
  void updateProductDetails(String selectedProductName) {
    for (var map in databaseArray) {
      if (map.containsKey('Products')) {
        final products = map['Products'] as List<dynamic>;
        for (var product in products) {
          if (product['name'] == selectedProductName) {
            setState(() {
              selectedPrice = product['price']?.toDouble();
              selectedOffcutPrice = product['offcutprice']?.toDouble();
              availableRolls = (product['rolls'] as List<dynamic>)
                  .map((roll) => roll.toString())
                  .toList();
              selectedRoll = null; // Reset roll selection
              rollCompatibilityError = null; // Clear any existing error
            });
            return;
          }
        }
      }
    }
    setState(() {
      selectedPrice = null;
      selectedOffcutPrice = null;
      availableRolls = [];
      selectedRoll = null;
      rollCompatibilityError = null;
    });
  }

  /// Validates roll compatibility with user input width
  void validateRollCompatibility() {
    if (selectedRoll == null) return;

    double rollWidth =
        double.tryParse(selectedRoll!) ?? 0.0; // Parse roll width
    double userWidth =
        getValueInFeet(widthController.text); // Get user width in feet

    setState(() {
      if (userWidth > rollWidth) {
        rollCompatibilityError =
            "Roll is not compatible for this width"; // Set error message
      } else {
        rollCompatibilityError = null; // Clear error if compatible
      }
    });
  }

  /// Calculates the offcut width if user input width is less than the roll width.
  /// Returns null if no roll is selected or the widths are invalid.
  double? calculateOffcutWidth() {
    if (selectedRoll == null) return null;

    double rollWidth =
        double.tryParse(selectedRoll!) ?? 0.0; // Parse roll width
    double userWidth =
        getValueInFeet(widthController.text); // Get user width in feet

    if (userWidth >= rollWidth) {
      return null; // No offcut if the user width is greater than or equal to the roll width
    }

    return rollWidth - userWidth; // Calculate offcut width
  }

  double calculateRingsPrice() {
    if (!includeRings) return 0.0; // Return 0 if rings are not included

    double ringsPrice = 0.0;

    // Loop through the databaseArray to find the 'Rings' product
    for (var map in databaseArray) {
      if (map.containsKey('Products')) {
        final products = map['Products'] as List<dynamic>;

        // Loop through the products to find the product with name 'Rings'
        for (var product in products) {
          if (product['name'] == 'Rings') {
            setState(() {
              // Get the price from the 'Rings' product
              ringsPrice = product['price']?.toDouble() ?? 0.0;
            });

            // Calculate total price based on number of rings
            double numberOfRings =
                double.tryParse(numberOfRingsController.text) ?? 0.0;
            return ringsPrice * numberOfRings; // Calculate and return the price
          }
        }
      }
    }

    return 0.0; // Return 0.0 if rings are not found in the database
  }

  double calculatePocketsPrice() {
    if (!includePockets) return 0.0; // Return 0 if pockets are not included

    double pocketsPrice = 0.0;

    // Loop through the databaseArray to find the 'Pocket' product
    for (var map in databaseArray) {
      if (map.containsKey('Products')) {
        final products = map['Products'] as List<dynamic>;

        // Loop through the products to find the product with name 'Pocket'
        for (var product in products) {
          if (product['name'] == 'Pocket') {
            setState(() {
              // Get the price from the 'Pocket' product
              pocketsPrice = product['price']?.toDouble() ?? 0.0;
            });

            // Calculate total price for pockets, multiplying by 2 as per the original logic
            return pocketsPrice * 2; // Return the calculated price
          }
        }
      }
    }

    return 0.0; // Return 0.0 if pocket is not found in the database
  }

  double calculateDesignPrice() {
    if (!includeDesign) return 0.0; // Return 0 if design is not included

    return double.tryParse(designPriceController.text) ?? 0.0;
  }

  /// Calculates the print area, offcut area, and their respective prices.
  /// Returns a map with all the calculated values.
  Map<String, dynamic> calculatePrices() {
    if (selectedPrice == null) {
      return {
        'printArea': null,
        'offcutArea': null,
        'priceAP': null,
        'priceOfA': null,
        'printPrice': null,
        'totalPrice': null,
      };
    }

    // Get dimensions in feet
    double widthInFeet = getValueInFeet(widthController.text);
    double heightInFeet = getValueInFeet(heightController.text);
    double areaP = widthInFeet * heightInFeet;

    // Calculate price for the main area
    double priceAP = areaP * selectedPrice!;

    // Check if offcut exists
    double? offcutWidth = calculateOffcutWidth();
    double priceOfA = 0.0;
    if (offcutWidth != null && selectedOffcutPrice != null) {
      double areaOf = offcutWidth * heightInFeet;
      priceOfA = areaOf * selectedOffcutPrice!;
    }

    // Calculate total print price
    double printPrice = priceAP + priceOfA;

    // Calculate additional prices
    double ringsPrice = calculateRingsPrice();
    double pocketsPrice = calculatePocketsPrice();
    double designPrice = calculateDesignPrice();

    // Calculate the total price
    double totalPrice = printPrice + ringsPrice + pocketsPrice + designPrice;

    return {
      'printArea': areaP,
      'offcutArea': offcutWidth != null ? offcutWidth * heightInFeet : null,
      'priceAP': priceAP,
      'priceOfA': priceOfA,
      'printPrice': printPrice,
      'ringsPrice': ringsPrice,
      'pocketsPrice': pocketsPrice,
      'designPrice': designPrice,
      'totalPrice': totalPrice,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Store the converted values in feet
    double widthInFeet = getValueInFeet(widthController.text);
    double heightInFeet = getValueInFeet(heightController.text);
    double? offcutWidth = calculateOffcutWidth(); // Calculate the offcut width
    // Perform calculations
    Map<String, dynamic> priceData = calculatePrices();

    return Scaffold(
      appBar: AppBar(
        title: Text('Width, Height & Firebase Data'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Dropdown for selecting between Feet or Inch
              DropdownButton<String>(
                value: unit,
                onChanged: (String? newValue) {
                  setState(() {
                    unit = newValue!;
                  });
                },
                items: <String>['Feet', 'Inch']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),

              SizedBox(height: 20),

              // Dropdown for selecting product name
              Text(
                'Select a product',
                style: TextStyle(fontSize: 16),
              ),
              DropdownButton<String>(
                value: selectedName,
                hint: Text("Select a product"),
                onChanged: (String? newName) {
                  setState(() {
                    selectedName = newName!;
                    updateProductDetails(newName);
                  });
                },
                items:
                    productNames.map<DropdownMenuItem<String>>((String name) {
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(name),
                  );
                }).toList(),
              ),

              SizedBox(height: 20),

              // Width input field
              TextField(
                controller: widthController,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    validateRollCompatibility(); // Re-validate on input change
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Width (${unit})',
                  border: OutlineInputBorder(),
                ),
              ),

              SizedBox(height: 20),

              // Height input field
              TextField(
                controller: heightController,
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    validateRollCompatibility(); // Re-validate on input change
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Height (${unit})',
                  border: OutlineInputBorder(),
                ),
              ),

              SizedBox(height: 20),

              // Dropdown for selecting rolls
              if (availableRolls.isNotEmpty)
                DropdownButton<String>(
                  value: selectedRoll,
                  hint: Text("Select a roll"),
                  onChanged: (String? newRoll) {
                    setState(() {
                      selectedRoll = newRoll!;
                      validateRollCompatibility(); // Validate on roll selection
                    });
                  },
                  items: availableRolls
                      .map<DropdownMenuItem<String>>((String roll) {
                    return DropdownMenuItem<String>(
                      value: roll,
                      child: Text(roll),
                    );
                  }).toList(),
                ),

              // Display roll compatibility error
              if (rollCompatibilityError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    rollCompatibilityError!,
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),

              SizedBox(height: 20),

              // // Display current state values
              Text(
                'Width: ${widthInFeet.toStringAsFixed(2)} Feet',
                style: TextStyle(fontSize: 10),
              ),
              Text(
                'Height: ${heightInFeet.toStringAsFixed(2)} Feet',
                style: TextStyle(fontSize: 10),
              ),
              // Text(
              //   'Unit: $unit',
              //   style: TextStyle(fontSize: 16),
              // ),
              Text(
                'Selected Product: ${selectedName ?? "None"}',
                style: TextStyle(fontSize: 10),
              ),
              // Text(
              //   'Selected Roll: ${selectedRoll ?? "None"}',
              //   style: TextStyle(fontSize: 16),
              // ),
              // Text(
              //   'Selected Roll Offcut price: ${selectedOffcutPrice ?? "None"}',
              //   style: TextStyle(fontSize: 16),
              // ),
              // Text(
              //   'Selected Roll price: ${selectedPrice ?? "None"}',
              //   style: TextStyle(fontSize: 16),
              // ),
              // // Display offcut width
              // if (offcutWidth != null)
              //   Text(
              //     'Offcut Width: ${offcutWidth.toStringAsFixed(2)} Feet',
              //     style: TextStyle(
              //         fontSize: 16,
              //         color: const Color.fromARGB(255, 255, 208, 0)),
              //   ),
              // // Display calculated values
              // if (priceData['printArea'] != null)
              //   Text(
              //     'Print Area: ${priceData['printArea'].toStringAsFixed(2)} Sq. Feet',
              //     style: TextStyle(fontSize: 16),
              //   ),
              // if (priceData['offcutArea'] != null)
              //   Text(
              //     'Offcut Area: ${priceData['offcutArea'].toStringAsFixed(2)} Sq. Feet',
              //     style: TextStyle(fontSize: 16),
              //   ),
              // if (priceData['priceAP'] != null)
              //   Text(
              //     'Price for Print Area (PriceAP): \$${priceData['priceAP'].toStringAsFixed(2)}',
              //     style: TextStyle(fontSize: 16),
              //   ),
              // if (priceData['priceOfA'] != null)
              //   Text(
              //     'Price for Offcut Area (PriceOfA): \$${priceData['priceOfA'].toStringAsFixed(2)}',
              //     style: TextStyle(fontSize: 16),
              //   ),
              // if (priceData['printPrice'] != null)
              //   Text(
              //     'Total Print Price: \$${priceData['printPrice'].toStringAsFixed(2)}',
              //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              //   ),
              // if (priceData['designPrice'] != null)
              //   Text(
              //     'Design Price: \$${priceData['designPrice'].toStringAsFixed(2)}',
              //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              //   ),

              // if (priceData['ringsPrice'] != null)
              //   Text(
              //     'Design Price: \$${priceData['ringsPrice'].toStringAsFixed(2)}',
              //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              //   ),

              // if (priceData['pocketsPrice'] != null)
              //   Text(
              //     'Design Price: \$${priceData['pocketsPrice'].toStringAsFixed(2)}',
              //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              //   ),

              // Organized GUI with side-by-side view for Print Area and Offcut Area
              Row(
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.lightBlue[50],
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Print Area: ${priceData['printArea']?.toStringAsFixed(2) ?? "N/A"} Sq. Feet',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Price: LKR ${selectedPrice ?? "None"}',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Price for Print Area: LKR ${priceData['priceAP']?.toStringAsFixed(2) ?? "N/A"}',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      color: Colors.yellow[50],
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offcut Area: ${offcutWidth?.toStringAsFixed(2) ?? "N/A"} X ${heightInFeet.toStringAsFixed(2)} = ${priceData['offcutArea']?.toStringAsFixed(2) ?? "N/A"} Sq. Feet',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Offcut price: LKR ${selectedOffcutPrice ?? "None"}',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            'Price for Offcut Area: LKR ${priceData['priceOfA']?.toStringAsFixed(2) ?? "N/A"}',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              ///Design price
              Row(
                children: [
                  Checkbox(
                    value: includeDesign,
                    onChanged: (bool? value) {
                      setState(() {
                        includeDesign = value ?? false;
                      });
                      calculatePrices();
                    },
                  ),
                  Text("Include Design Price"),
                ],
              ),

              // Input for Design Price
              if (includeDesign)
                TextField(
                  controller: designPriceController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      validateRollCompatibility(); // Re-validate on input change
                    });
                    calculatePrices();
                  },
                  decoration: InputDecoration(
                    labelText: 'Design Price',
                    border: OutlineInputBorder(),
                  ),
                ),

              SizedBox(height: 20),

              ///Rings
              // Checkbox for Rings
              Row(
                children: [
                  Checkbox(
                    value: includeRings,
                    onChanged: (bool? value) {
                      setState(() {
                        includeRings = value ?? false;
                      });
                      calculatePrices();
                    },
                  ),
                  Text("Include Rings"),
                ],
              ),

              // Input for Number of Rings
              if (includeRings)
                TextField(
                  controller: numberOfRingsController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      validateRollCompatibility(); // Re-validate on input change
                    });
                    calculatePrices();
                  },
                  decoration: InputDecoration(
                    labelText: 'Number of Rings',
                    border: OutlineInputBorder(),
                  ),
                ),

              SizedBox(height: 20),

              //pockets
              // Checkbox for Pockets
              Row(
                children: [
                  Checkbox(
                    value: includePockets,
                    onChanged: (bool? value) {
                      setState(() {
                        includePockets = value ?? false;
                      });
                      calculatePrices();
                    },
                  ),
                  Text("Include Pockets"),
                ],
              ),

              SizedBox(height: 20),

              Divider(
                color: Colors.grey, // Line color
                thickness: 1, // Line thickness
                indent: 5, // Empty space to the left of the line
                endIndent: 5, // Empty space to the right of the line
              ),
              if (priceData['printPrice'] != null)
                Text(
                  'Print: LKR ${priceData['printPrice'].toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              SizedBox(height: 20),

              if (priceData['designPrice'] != null)
                Text(
                  'Design: LKR ${priceData['designPrice'].toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              SizedBox(height: 20),

              if (priceData['ringsPrice'] != null)
                Text(
                  'Rings: LKR ${priceData['ringsPrice'].toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              SizedBox(height: 20),

              if (priceData['pocketsPrice'] != null)
                Text(
                  'Pockets: LKR ${priceData['pocketsPrice'].toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              Divider(
                color: Colors.grey, // Line color
                thickness: 1, // Line thickness
                indent: 5, // Empty space to the left of the line
                endIndent: 5, // Empty space to the right of the line
              ),

              if (priceData['totalPrice'] != null)
                Text(
                  'Grand Total Price: LKR ${priceData['totalPrice'].toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: const Color(0xFF000A99)),
                ),
              SizedBox(height: 30),

              
            ],
          ),
        ),
      ),
    );
  }
}
