// dllmain.cpp : Defines the entry point for the DLL application.

#include "pch.h"

#include <Python.h>
#include <cstring>
#include <iostream>
#include <string>

using namespace std;

#pragma pack(4)
struct MqlRates {
  INT64 time;         // Period start time
  double open;        // Open price
  double high;        // The highest price of the period
  double low;         // The lowest price of the period
  double close;       // Close price
  UINT64 tick_volume; // Tick volume
  INT32 spread;       // Spread
  UINT64 real_volume; // Trade volume
};

// Create some Python objects that will later be assigned values.
PyObject *pName, *pModule, *pDict, *pFunc, *pArgs, *pValue;

// Initialize the Python interpreter.
void InitPython() {
  Py_Initialize();
  PySys_SetPath(L"C:\\Program Files\\Python38;\
C:\\Program Files\\Python38\\DLLs;\
C:\\Program Files\\Python38\\Lib;\
C:\\Program Files\\Python38\\Lib\\site-packages;\
C:\\Users\\Kelvin\\AppData\\Roaming\\Python\\Python38\\site-packages;\
C:\\Users\\Kelvin\\AppData\\Roaming\\Python\\Python38\\site-packages\\Pythonwin;\
C:\\Users\\Kelvin\\AppData\\Roaming\\Python\\Python38\\site-packages\\win32;\
C:\\Users\\Kelvin\\AppData\\Roaming\\Python\\Python38\\site-packages\\win32\\lib;\
C:\\Projects\\quantsmono\\Python\\etfc\\");
}

// __declspec(dllexport) int TB_Test(char *buffer) {
//   InitPython();

//   // Import the file as a Python module.
//   pModule = PyImport_ImportModule("example");

//   if (pModule == NULL)
//     return -1000;

//   // Create a dictionary for the contents of the module.
//   pDict = PyModule_GetDict(pModule);

//   if (pDict == NULL)
//     return -2000;

//   // Get the add method from the dictionary.
//   pFunc = PyDict_GetItemString(pDict, "con_test");

//   // Call the function with the arguments.
//   PyObject *pResult = PyObject_CallObject(pFunc, NULL);

//   // Print a message if calling the method failed.
//   if (pResult == NULL)
//     return -3000;

//   int num = 0;
//   PyObject *text;
//   if (PyArg_ParseTuple(pResult, "Oi", &text, &num)) {

//     Py_ssize_t size;
//     const char *data = PyUnicode_AsUTF8AndSize(text, &size);

//     strcpy_s(buffer, size + 1, data);
//   }

//   return num;
// }

__declspec(dllexport) int TB_Init() {
  InitPython();

  // Import the file as a Python module.
  pModule = PyImport_ImportModule("etfc-prod");

  if (pModule == NULL)
    return -1000;

  // Create a dictionary for the contents of the module.
  pDict = PyModule_GetDict(pModule);

  if (pDict == NULL)
    return -2000;

  return 0;
}

// __declspec(dllexport) int TB_Load(char *errorBuffer) {
//   // Get the add method from the dictionary.
//   pFunc = PyDict_GetItemString(pDict, "con_load");

//   // Call the function with the arguments.
//   PyObject *pResult = PyObject_CallObject(pFunc, NULL);

//   // Print a message if calling the method failed.
//   if (pResult == NULL)
//     return -3000;

//   int resultCode = 0;
//   PyObject *pErrorText;
//   if (PyArg_ParseTuple(pResult, "iO", &resultCode, &pErrorText)) {
//     Py_ssize_t size;
//     const char *errorText = PyUnicode_AsUTF8AndSize(pErrorText, &size);

//     strcpy_s(errorBuffer, size + 1, errorText);
//   }

//   return resultCode;
// }

int IMAGE_LENGTH_M15 = 48 + 5;
int IMAGE_LENGTH_H1 = 48 + 5;
int IMAGE_LENGTH_H4 = 24 + 5;
int IMAGE_LENGTH_M5 = 24 + 5;
int IMAGE_LENGTH_D1 = 7 + 5;

PyObject *CopyRatesToList(char *errorBuffer, MqlRates *rates, int size) {
  PyObject *listObj = PyList_New(size);

  if (!listObj) {
    string s("Unable to allocate memory for Python list");
    strcpy_s(errorBuffer, s.size() + 1, s.c_str());
    return NULL;
  }

  for (unsigned int i = 0; i < size; ++i) {
    MqlRates rt = rates[i];
    PyObject* pRate = PyList_New(6);
    // PyObject *pRate = PyTuple_New(6);

    if (!pRate) {
      string s("Unable to allocate memory for Python list " + i);
      strcpy_s(errorBuffer, s.size() + 1, s.c_str());
      return NULL;
    }

    // PyTuple_SetItem(pRate, 0, PyFloat_FromDouble(rt.open));
    // PyTuple_SetItem(pRate, 1, PyFloat_FromDouble(rt.high));
    // PyTuple_SetItem(pRate, 2, PyFloat_FromDouble(rt.low));
    // PyTuple_SetItem(pRate, 3, PyFloat_FromDouble(rt.close));
    // PyTuple_SetItem(pRate, 4, PyLong_FromLong(rt.tick_volume));
    // PyTuple_SetItem(pRate, 5, PyLong_FromLong(rt.time));

    PyList_SetItem(pRate, 0, PyFloat_FromDouble(rt.open));
    PyList_SetItem(pRate, 1, PyFloat_FromDouble(rt.high));
    PyList_SetItem(pRate, 2, PyFloat_FromDouble(rt.low));
    PyList_SetItem(pRate, 3, PyFloat_FromDouble(rt.close));
    PyList_SetItem(pRate, 4, PyLong_FromLong(rt.tick_volume));
    PyList_SetItem(pRate, 5, PyLong_FromLong(rt.time));

    PyList_SetItem(listObj, i, pRate);
  }

  return listObj;
}

__declspec(dllexport) int TB_Predict(char *errorBuffer, MqlRates *ratesM5,
                                     MqlRates *ratesM15, MqlRates *ratesH1,
                                     MqlRates *ratesH4, MqlRates *ratesD1) {
  // Get the add method from the dictionary.
  pFunc = PyDict_GetItemString(pDict, "con_predict");

  pArgs = PyTuple_New(5);

  // Set the Python int as the first and second arguments to the method.
  PyTuple_SetItem(pArgs, 0, CopyRatesToList(errorBuffer, ratesM5, IMAGE_LENGTH_M5));
  PyTuple_SetItem(pArgs, 1, CopyRatesToList(errorBuffer, ratesM15, IMAGE_LENGTH_M15));
  PyTuple_SetItem(pArgs, 2, CopyRatesToList(errorBuffer, ratesH1, IMAGE_LENGTH_H1));
  PyTuple_SetItem(pArgs, 3, CopyRatesToList(errorBuffer, ratesH4, IMAGE_LENGTH_H4));
  PyTuple_SetItem(pArgs, 4, CopyRatesToList(errorBuffer, ratesD1, IMAGE_LENGTH_D1));

  // Call the function with the arguments.
  PyObject *pResult = PyObject_CallObject(pFunc, pArgs);

  // Print a message if calling the method failed.
  if (pResult == NULL)
    return -4000;

  int resultCode = -1;
  PyObject *pErrorText;
  if (PyArg_ParseTuple(pResult, "iO", &resultCode, &pErrorText)) {
    Py_ssize_t size;
    const char *errorText = PyUnicode_AsUTF8AndSize(pErrorText, &size);

    strcpy_s(errorBuffer, size + 1, errorText);
  }

  return resultCode;
}

__declspec(dllexport) int TB_Deinit() {
  // Destroy the Python interpreter.
  Py_Finalize();

  return 0;
}
