//! C-compatible wrapper around Nickel for Julia FFI
//!
//! This library provides C-compatible functions that can be called from Julia
//! via ccall/FFI to evaluate Nickel code without spawning a subprocess.
//!
//! # Functions
//!
//! - `nickel_eval_string`: Evaluate Nickel code and return JSON string
//! - `nickel_eval_native`: Evaluate Nickel code and return binary-encoded native types
//! - `nickel_get_error`: Get the last error message
//! - `nickel_free_string`: Free allocated string memory
//! - `nickel_free_buffer`: Free allocated binary buffer

use std::ffi::{CStr, CString};
use std::io::Cursor;
use std::os::raw::c_char;
use std::ptr;

use nickel_lang_core::eval::cache::lazy::CBNCache;
use nickel_lang_core::program::Program;
use nickel_lang_core::serialize::{self, ExportFormat};
use nickel_lang_core::term::{RichTerm, Term};

use malachite::rounding_modes::RoundingMode;
use malachite::num::conversion::traits::RoundingFrom;

// Thread-local storage for the last error message
thread_local! {
    static LAST_ERROR: std::cell::RefCell<Option<CString>> = const { std::cell::RefCell::new(None) };
}

// Type tags for binary protocol
const TYPE_NULL: u8 = 0;
const TYPE_BOOL: u8 = 1;
const TYPE_INT: u8 = 2;
const TYPE_FLOAT: u8 = 3;
const TYPE_STRING: u8 = 4;
const TYPE_ARRAY: u8 = 5;
const TYPE_RECORD: u8 = 6;
const TYPE_ENUM: u8 = 7;

/// Result buffer for native evaluation
#[repr(C)]
pub struct NativeBuffer {
    pub data: *mut u8,
    pub len: usize,
}

/// Evaluate a Nickel code string and return the result as a JSON string.
///
/// # Safety
/// - `code` must be a valid null-terminated C string
/// - The returned pointer must be freed with `nickel_free_string`
/// - Returns NULL on error; use `nickel_get_error` to retrieve error message
#[no_mangle]
pub unsafe extern "C" fn nickel_eval_string(code: *const c_char) -> *const c_char {
    if code.is_null() {
        set_error("Null pointer passed to nickel_eval_string");
        return ptr::null();
    }

    let code_str = match CStr::from_ptr(code).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_error(&format!("Invalid UTF-8 in input: {}", e));
            return ptr::null();
        }
    };

    match eval_nickel_json(code_str) {
        Ok(json) => {
            match CString::new(json) {
                Ok(cstr) => cstr.into_raw(),
                Err(e) => {
                    set_error(&format!("Result contains null byte: {}", e));
                    ptr::null()
                }
            }
        }
        Err(e) => {
            set_error(&e);
            ptr::null()
        }
    }
}

/// Evaluate Nickel code and return binary-encoded native types.
///
/// Binary protocol:
/// - Type tag (1 byte): 0=Null, 1=Bool, 2=Int64, 3=Float64, 4=String, 5=Array, 6=Record
/// - Value data (varies by type)
///
/// # Safety
/// - `code` must be a valid null-terminated C string
/// - The returned buffer must be freed with `nickel_free_buffer`
/// - Returns NativeBuffer with null data on error; use `nickel_get_error` for message
#[no_mangle]
pub unsafe extern "C" fn nickel_eval_native(code: *const c_char) -> NativeBuffer {
    let null_buffer = NativeBuffer { data: ptr::null_mut(), len: 0 };

    if code.is_null() {
        set_error("Null pointer passed to nickel_eval_native");
        return null_buffer;
    }

    let code_str = match CStr::from_ptr(code).to_str() {
        Ok(s) => s,
        Err(e) => {
            set_error(&format!("Invalid UTF-8 in input: {}", e));
            return null_buffer;
        }
    };

    match eval_nickel_native(code_str) {
        Ok(buffer) => {
            let len = buffer.len();
            let boxed = buffer.into_boxed_slice();
            let data = Box::into_raw(boxed) as *mut u8;
            NativeBuffer { data, len }
        }
        Err(e) => {
            set_error(&e);
            null_buffer
        }
    }
}

/// Internal function to evaluate Nickel code and return JSON.
fn eval_nickel_json(code: &str) -> Result<String, String> {
    let source = Cursor::new(code.as_bytes());
    let mut program: Program<CBNCache> = Program::new_from_source(source, "<ffi>", std::io::sink())
        .map_err(|e| format!("Parse error: {}", e))?;

    let result = program
        .eval_full_for_export()
        .map_err(|e| program.report_as_str(e))?;

    serialize::to_string(ExportFormat::Json, &result)
        .map_err(|e| format!("Serialization error: {:?}", e))
}

/// Internal function to evaluate Nickel code and return binary-encoded native types.
fn eval_nickel_native(code: &str) -> Result<Vec<u8>, String> {
    let source = Cursor::new(code.as_bytes());
    let mut program: Program<CBNCache> = Program::new_from_source(source, "<ffi>", std::io::sink())
        .map_err(|e| format!("Parse error: {}", e))?;

    let result = program
        .eval_full_for_export()
        .map_err(|e| program.report_as_str(e))?;

    let mut buffer = Vec::new();
    encode_term(&result, &mut buffer)?;
    Ok(buffer)
}

/// Encode a Nickel term to binary format
fn encode_term(term: &RichTerm, buffer: &mut Vec<u8>) -> Result<(), String> {
    match term.as_ref() {
        Term::Null => {
            buffer.push(TYPE_NULL);
        }
        Term::Bool(b) => {
            buffer.push(TYPE_BOOL);
            buffer.push(if *b { 1 } else { 0 });
        }
        Term::Num(n) => {
            // Convert to f64 using nearest rounding mode
            let (f, _) = f64::rounding_from(n, RoundingMode::Nearest);
            // Try to represent as integer if possible
            if f.fract() == 0.0 && f >= i64::MIN as f64 && f <= i64::MAX as f64 {
                buffer.push(TYPE_INT);
                buffer.extend_from_slice(&(f as i64).to_le_bytes());
            } else {
                buffer.push(TYPE_FLOAT);
                buffer.extend_from_slice(&f.to_le_bytes());
            }
        }
        Term::Str(s) => {
            buffer.push(TYPE_STRING);
            let bytes = s.as_str().as_bytes();
            buffer.extend_from_slice(&(bytes.len() as u32).to_le_bytes());
            buffer.extend_from_slice(bytes);
        }
        Term::Array(arr, _) => {
            buffer.push(TYPE_ARRAY);
            buffer.extend_from_slice(&(arr.len() as u32).to_le_bytes());
            for elem in arr.iter() {
                encode_term(elem, buffer)?;
            }
        }
        Term::Record(record) => {
            buffer.push(TYPE_RECORD);
            let fields: Vec<_> = record.fields.iter().collect();
            buffer.extend_from_slice(&(fields.len() as u32).to_le_bytes());
            for (key, field) in fields {
                // Encode field name
                let key_bytes = key.label().as_bytes();
                buffer.extend_from_slice(&(key_bytes.len() as u32).to_le_bytes());
                buffer.extend_from_slice(key_bytes);
                // Encode field value
                if let Some(ref value) = field.value {
                    encode_term(value, buffer)?;
                } else {
                    buffer.push(TYPE_NULL);
                }
            }
        }
        Term::Enum(tag) => {
            // Simple enum without argument
            // Format: TYPE_ENUM | tag_len (u32) | tag_bytes | has_arg (u8 = 0)
            buffer.push(TYPE_ENUM);
            let tag_bytes = tag.label().as_bytes();
            buffer.extend_from_slice(&(tag_bytes.len() as u32).to_le_bytes());
            buffer.extend_from_slice(tag_bytes);
            buffer.push(0); // no argument
        }
        Term::EnumVariant { tag, arg, .. } => {
            // Enum with argument
            // Format: TYPE_ENUM | tag_len (u32) | tag_bytes | has_arg (u8 = 1) | arg_value
            buffer.push(TYPE_ENUM);
            let tag_bytes = tag.label().as_bytes();
            buffer.extend_from_slice(&(tag_bytes.len() as u32).to_le_bytes());
            buffer.extend_from_slice(tag_bytes);
            buffer.push(1); // has argument
            encode_term(arg, buffer)?;
        }
        other => {
            return Err(format!("Unsupported term type for native encoding: {:?}", other));
        }
    }
    Ok(())
}

/// Get the last error message.
///
/// # Safety
/// - The returned pointer is valid until the next call to any nickel_* function
/// - Do not free this pointer; it is managed internally
#[no_mangle]
pub unsafe extern "C" fn nickel_get_error() -> *const c_char {
    LAST_ERROR.with(|e| {
        e.borrow()
            .as_ref()
            .map(|s| s.as_ptr())
            .unwrap_or(ptr::null())
    })
}

/// Free a string allocated by this library.
///
/// # Safety
/// - `ptr` must have been returned by `nickel_eval_string`
/// - `ptr` must not be used after this call
/// - Passing NULL is safe (no-op)
#[no_mangle]
pub unsafe extern "C" fn nickel_free_string(ptr: *const c_char) {
    if !ptr.is_null() {
        drop(CString::from_raw(ptr as *mut c_char));
    }
}

/// Free a binary buffer allocated by this library.
///
/// # Safety
/// - `buffer` must have been returned by `nickel_eval_native`
/// - The buffer must not be used after this call
#[no_mangle]
pub unsafe extern "C" fn nickel_free_buffer(buffer: NativeBuffer) {
    if !buffer.data.is_null() && buffer.len > 0 {
        let _ = Box::from_raw(std::slice::from_raw_parts_mut(buffer.data, buffer.len));
    }
}

fn set_error(msg: &str) {
    LAST_ERROR.with(|e| {
        *e.borrow_mut() = CString::new(msg).ok();
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    #[test]
    fn test_null_input() {
        unsafe {
            let result = nickel_eval_string(ptr::null());
            assert!(result.is_null());
            let error = nickel_get_error();
            assert!(!error.is_null());
        }
    }

    #[test]
    fn test_free_null() {
        unsafe {
            nickel_free_string(ptr::null());
        }
    }

    #[test]
    fn test_eval_simple_number() {
        unsafe {
            let code = CString::new("1 + 2").unwrap();
            let result = nickel_eval_string(code.as_ptr());
            assert!(!result.is_null(), "Expected result, got error: {:?}",
                CStr::from_ptr(nickel_get_error()).to_str());
            let result_str = CStr::from_ptr(result).to_str().unwrap();
            assert_eq!(result_str, "3");
            nickel_free_string(result);
        }
    }

    #[test]
    fn test_eval_string() {
        unsafe {
            let code = CString::new(r#""hello""#).unwrap();
            let result = nickel_eval_string(code.as_ptr());
            assert!(!result.is_null(), "Expected result, got error: {:?}",
                CStr::from_ptr(nickel_get_error()).to_str());
            let result_str = CStr::from_ptr(result).to_str().unwrap();
            assert_eq!(result_str, "\"hello\"");
            nickel_free_string(result);
        }
    }

    #[test]
    fn test_eval_record() {
        unsafe {
            let code = CString::new("{ x = 1, y = 2 }").unwrap();
            let result = nickel_eval_string(code.as_ptr());
            assert!(!result.is_null(), "Expected result, got error: {:?}",
                CStr::from_ptr(nickel_get_error()).to_str());
            let result_str = CStr::from_ptr(result).to_str().unwrap();
            assert!(result_str.contains("\"x\""));
            assert!(result_str.contains("\"y\""));
            nickel_free_string(result);
        }
    }

    #[test]
    fn test_eval_array() {
        unsafe {
            let code = CString::new("[1, 2, 3]").unwrap();
            let result = nickel_eval_string(code.as_ptr());
            assert!(!result.is_null(), "Expected result, got error: {:?}",
                CStr::from_ptr(nickel_get_error()).to_str());
            let result_str = CStr::from_ptr(result).to_str().unwrap();
            assert!(result_str.contains("1"));
            assert!(result_str.contains("2"));
            assert!(result_str.contains("3"));
            nickel_free_string(result);
        }
    }

    #[test]
    fn test_eval_function_application() {
        unsafe {
            let code = CString::new("let add = fun x y => x + y in add 3 4").unwrap();
            let result = nickel_eval_string(code.as_ptr());
            assert!(!result.is_null(), "Expected result, got error: {:?}",
                CStr::from_ptr(nickel_get_error()).to_str());
            let result_str = CStr::from_ptr(result).to_str().unwrap();
            assert_eq!(result_str, "7");
            nickel_free_string(result);
        }
    }

    #[test]
    fn test_eval_syntax_error() {
        unsafe {
            let code = CString::new("{ x = }").unwrap();
            let result = nickel_eval_string(code.as_ptr());
            assert!(result.is_null());
            let error = nickel_get_error();
            assert!(!error.is_null());
            let error_str = CStr::from_ptr(error).to_str().unwrap();
            assert!(!error_str.is_empty());
        }
    }

    #[test]
    fn test_native_int() {
        unsafe {
            let code = CString::new("42").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_INT);
            let value = i64::from_le_bytes(data[1..9].try_into().unwrap());
            assert_eq!(value, 42);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_float() {
        unsafe {
            let code = CString::new("3.14").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            if buffer.data.is_null() {
                let err = nickel_get_error();
                if !err.is_null() {
                    panic!("Error: {:?}", CStr::from_ptr(err).to_str());
                }
            }
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_FLOAT);
            let value = f64::from_le_bytes(data[1..9].try_into().unwrap());
            assert!((value - 3.14).abs() < 0.001);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_string() {
        unsafe {
            let code = CString::new(r#""hello""#).unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_STRING);
            let len = u32::from_le_bytes(data[1..5].try_into().unwrap()) as usize;
            let s = std::str::from_utf8(&data[5..5+len]).unwrap();
            assert_eq!(s, "hello");
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_bool() {
        unsafe {
            let code = CString::new("true").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_BOOL);
            assert_eq!(data[1], 1);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_array() {
        unsafe {
            let code = CString::new("[1, 2, 3]").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_ARRAY);
            let len = u32::from_le_bytes(data[1..5].try_into().unwrap());
            assert_eq!(len, 3);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_record() {
        unsafe {
            let code = CString::new("{ x = 1 }").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_RECORD);
            let field_count = u32::from_le_bytes(data[1..5].try_into().unwrap());
            assert_eq!(field_count, 1);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_eval_json_internal() {
        let result = eval_nickel_json("42").unwrap();
        assert_eq!(result, "42");

        let result = eval_nickel_json("{ a = 1 }").unwrap();
        assert!(result.contains("\"a\""));
        assert!(result.contains("1"));
    }

    // Comprehensive tests for all Nickel types

    #[test]
    fn test_native_null() {
        unsafe {
            let code = CString::new("null").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_NULL);
            assert_eq!(buffer.len, 1);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_bool_false() {
        unsafe {
            let code = CString::new("false").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_BOOL);
            assert_eq!(data[1], 0);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_negative_int() {
        unsafe {
            let code = CString::new("-42").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_INT);
            let value = i64::from_le_bytes(data[1..9].try_into().unwrap());
            assert_eq!(value, -42);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_large_int() {
        unsafe {
            let code = CString::new("1000000000000").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_INT);
            let value = i64::from_le_bytes(data[1..9].try_into().unwrap());
            assert_eq!(value, 1000000000000i64);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_negative_float() {
        unsafe {
            let code = CString::new("-2.718").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_FLOAT);
            let value = f64::from_le_bytes(data[1..9].try_into().unwrap());
            assert!((value - (-2.718)).abs() < 0.001);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_empty_string() {
        unsafe {
            let code = CString::new(r#""""#).unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_STRING);
            let len = u32::from_le_bytes(data[1..5].try_into().unwrap()) as usize;
            assert_eq!(len, 0);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_unicode_string() {
        unsafe {
            let code = CString::new(r#""hello 世界 🌍""#).unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_STRING);
            let len = u32::from_le_bytes(data[1..5].try_into().unwrap()) as usize;
            let s = std::str::from_utf8(&data[5..5+len]).unwrap();
            assert_eq!(s, "hello 世界 🌍");
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_empty_array() {
        unsafe {
            let code = CString::new("[]").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_ARRAY);
            let len = u32::from_le_bytes(data[1..5].try_into().unwrap());
            assert_eq!(len, 0);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_mixed_array() {
        unsafe {
            // Array with int, string, bool
            let code = CString::new(r#"[1, "two", true]"#).unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_ARRAY);
            let len = u32::from_le_bytes(data[1..5].try_into().unwrap());
            assert_eq!(len, 3);
            // First element: int 1
            assert_eq!(data[5], TYPE_INT);
            // (rest of elements follow)
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_nested_array() {
        unsafe {
            let code = CString::new("[[1, 2], [3, 4]]").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_ARRAY);
            let len = u32::from_le_bytes(data[1..5].try_into().unwrap());
            assert_eq!(len, 2);
            // First element should be an array
            assert_eq!(data[5], TYPE_ARRAY);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_empty_record() {
        unsafe {
            let code = CString::new("{}").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_RECORD);
            let field_count = u32::from_le_bytes(data[1..5].try_into().unwrap());
            assert_eq!(field_count, 0);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_nested_record() {
        unsafe {
            let code = CString::new("{ outer = { inner = 42 } }").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_RECORD);
            let field_count = u32::from_le_bytes(data[1..5].try_into().unwrap());
            assert_eq!(field_count, 1);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_record_with_mixed_types() {
        unsafe {
            let code = CString::new(r#"{ name = "test", count = 42, active = true, data = null }"#).unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_RECORD);
            let field_count = u32::from_le_bytes(data[1..5].try_into().unwrap());
            assert_eq!(field_count, 4);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_computed_value() {
        unsafe {
            let code = CString::new("let x = 10 in let y = 20 in x + y").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_INT);
            let value = i64::from_le_bytes(data[1..9].try_into().unwrap());
            assert_eq!(value, 30);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_function_result() {
        unsafe {
            let code = CString::new("let double = fun x => x * 2 in double 21").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_INT);
            let value = i64::from_le_bytes(data[1..9].try_into().unwrap());
            assert_eq!(value, 42);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_array_operations() {
        unsafe {
            // Test array map
            let code = CString::new("[1, 2, 3] |> std.array.map (fun x => x * 2)").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_ARRAY);
            let len = u32::from_le_bytes(data[1..5].try_into().unwrap());
            assert_eq!(len, 3);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_record_merge() {
        unsafe {
            let code = CString::new("{ a = 1 } & { b = 2 }").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            assert_eq!(data[0], TYPE_RECORD);
            let field_count = u32::from_le_bytes(data[1..5].try_into().unwrap());
            assert_eq!(field_count, 2);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_json_all_types() {
        // Test JSON serialization for all types
        assert_eq!(eval_nickel_json("null").unwrap(), "null");
        assert_eq!(eval_nickel_json("true").unwrap(), "true");
        assert_eq!(eval_nickel_json("false").unwrap(), "false");
        assert_eq!(eval_nickel_json("42").unwrap(), "42");
        assert!(eval_nickel_json("3.14").unwrap().starts_with("3.14"));
        assert_eq!(eval_nickel_json(r#""hello""#).unwrap(), "\"hello\"");
        assert!(eval_nickel_json("[]").unwrap().contains("[]") || eval_nickel_json("[]").unwrap().contains("[\n]"));
    }

    #[test]
    fn test_native_simple_enum() {
        unsafe {
            let code = CString::new("let x = 'Foo in x").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            // TYPE_ENUM | tag_len | "Foo" | has_arg=0
            assert_eq!(data[0], TYPE_ENUM);
            let tag_len = u32::from_le_bytes(data[1..5].try_into().unwrap()) as usize;
            assert_eq!(tag_len, 3); // "Foo"
            assert_eq!(&data[5..8], b"Foo");
            assert_eq!(data[8], 0); // no argument
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_enum_variant() {
        unsafe {
            let code = CString::new("let x = 'Some 42 in x").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            // TYPE_ENUM | tag_len | "Some" | has_arg=1 | TYPE_INT | 42
            assert_eq!(data[0], TYPE_ENUM);
            let tag_len = u32::from_le_bytes(data[1..5].try_into().unwrap()) as usize;
            assert_eq!(tag_len, 4); // "Some"
            assert_eq!(&data[5..9], b"Some");
            assert_eq!(data[9], 1); // has argument
            assert_eq!(data[10], TYPE_INT);
            nickel_free_buffer(buffer);
        }
    }

    #[test]
    fn test_native_enum_with_record() {
        unsafe {
            let code = CString::new("let x = 'Ok { value = 123 } in x").unwrap();
            let buffer = nickel_eval_native(code.as_ptr());
            assert!(!buffer.data.is_null());
            let data = std::slice::from_raw_parts(buffer.data, buffer.len);
            // TYPE_ENUM | tag_len | "Ok" | has_arg=1 | TYPE_RECORD | ...
            assert_eq!(data[0], TYPE_ENUM);
            let tag_len = u32::from_le_bytes(data[1..5].try_into().unwrap()) as usize;
            assert_eq!(tag_len, 2); // "Ok"
            assert_eq!(&data[5..7], b"Ok");
            assert_eq!(data[7], 1); // has argument
            assert_eq!(data[8], TYPE_RECORD);
            nickel_free_buffer(buffer);
        }
    }
}
