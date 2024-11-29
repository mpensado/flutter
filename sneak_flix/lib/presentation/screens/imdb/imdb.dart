import 'package:flutter/material.dart';
import 'dart:convert'; // Para convertir respuestas JSON
import 'package:http/http.dart' as http;
import 'package:sneak_flix/config/helpers/tools.dart'; // Para realizar solicitudes HTTP

class ImDb extends StatefulWidget {
  const ImDb({super.key});

  @override
  _ImDbState createState() => _ImDbState();
}

class _ImDbState extends State<ImDb> {
  final String apiKey =
      "53db118f20msh670875a9ffa77e1p17715ejsn646b8895ca65"; // Reemplázala con tu clave de uNoGS
  final String omdbApiKey = "c718f108"; // Reemplázala con tu clave API de OMDb
  final String baseUrl = "https://unogsng.p.rapidapi.com"; // Endpoint base
  List<dynamic> results = []; // Para almacenar los resultados

  // Future<void> fetchNetflixTitles(String query) async {
  //   final url = Uri.parse('$baseUrl/search?query=$query&limit=100'); // País: México (78)
  //   final headers = {
  //     "X-RapidAPI-Key": apiKey,
  //     "X-RapidAPI-Host": "unogsng.p.rapidapi.com",
  //   };

  //   try {
  //     final response = await http.get(url, headers: headers);
  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       setState(() {
  //         results = data['results'];
  //       });
  //     } else {
  //       throw Exception('Error en la solicitud: ${response.statusCode}');
  //     }
  //   } catch (e) {
  //     print('Error: $e');
  //   }
  // }

  Future<void> fetchImdbTitles(String title) async {
    final url =
        Uri.parse('https://www.omdbapi.com/?s=$title&apikey=$omdbApiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> fetchedResults = data['Search'] ?? [];
        final List<dynamic> nexflixResults = [];
        for (var item in fetchedResults) {
          final imdbRating = await fetchImdbRating(item['Title']);
          item['imdbRating'] = imdbRating;
          final id = await validateNetflixTitle(item['Title']);
          if (id != "") {
            item['netflixId'] = id;
            nexflixResults.add(item);
          }
        }

        setState(() {
          results = nexflixResults;
        });
      } else {
        throw Exception('Error en OMDb API: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Future<String> validateNetflixTitle(String query) async {
    final url = Uri.parse('$baseUrl/search?query=$query');
    final headers = {
      "X-RapidAPI-Key": apiKey,
      "X-RapidAPI-Host": "unogsng.p.rapidapi.com",
    };

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String nfid = "";
        final List<dynamic> fetchedResults = data['results'] ?? [];
        nfid = fetchedResults.isNotEmpty ? fetchedResults[0]['nfid'].toString(): "";
        return nfid;
        //return fetchedResults[''];
      } else {
        throw Exception('Error en uNoGS API: ${response.statusCode}');
      }
    } catch (e) {
      return "";
    }
  }

  Future<String?> fetchImdbRating(String title) async {
    final url =
        Uri.parse('https://www.omdbapi.com/?t=$title&apikey=$omdbApiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['imdbRating'] ?? 'N/A'; // Devuelve la calificación o 'N/A'
      } else {
        throw Exception('Error en OMDb API: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  Future<void> fetchNetflixTitles(String query) async {
    final url = Uri.parse('$baseUrl/search?query=$query');
    final headers = {
      "X-RapidAPI-Key": apiKey,
      "X-RapidAPI-Host": "unogsng.p.rapidapi.com",
    };

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> fetchedResults = data['results'] ?? [];

        // Iterar para obtener la calificación de IMDb de cada título
        for (var item in fetchedResults) {
          final imdbRating = await fetchImdbRating(item['title']);
          item['imdbRating'] = imdbRating; // Añade la calificación al elemento
        }

        setState(() {
          results = fetchedResults;
        });
      } else {
        throw Exception('Error en uNoGS API: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buscar en Netflix"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar títulos',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  fetchImdbTitles(value); //fetchNetflixTitles(value);
                }
              },
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final item = results[index];
                  return Card(
                    child: InkWell(
                          onTap: () {
                            item['netflixId'] == ""? null: Tools.launchURL("https://www.netflix.com/title/${item['netflixId']}");
                          },
                          child: ListTile(
                            title: Text("${item['Title'] ?? 'Sin título'} - ${item['netflixId'] ?? 'N/A'}"),
                            subtitle: Text("Año: ${item['Year'] ?? 'N/A'}"),
                            trailing: Text("IMDB: ${item['imdbRating'] ?? 'N/A'}"),
                          ),
                        ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
