//! C-compatible wrapper around Nickel for Julia FFI
//!
//! This library provides C-compatible functions that can be called from Julia
//! via ccall/FFI to evaluate Nickel code without spawning a subprocess.
//!
//! # Functions
//!
//! - `nickel_eval_string`: Evaluate Nickel code and return JSON string
//! - `nickel_get_error`: Get the last error message
//! - `nickel_free_string`: Free allocated string memory

use std::ffi::{CStr, CString};
use std::io::Cursor;
use std::os::raw::c_char;
use std::ptr;

use nickel_lang_core::eval::cache::lazy::CBNCache;
use nickel_lang_core::program::Program;
use nickel_lang_core::serialize::{self, ExportFormat};

// Thread-local storage for the last error message
thread_local! {
    static LAST_ERROR: std::cell::RefCell<Option<CString>> = const { std::cell::RefCell::new(None) };
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

    match eval_nickel(code_str) {
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

/// Internal function to evaluate Nickel code and return JSON.
fn eval_nickel(code: &str) -> Result<String, String> {
    // Create a source from the code string
    let source = Cursor::new(code.as_bytes());

    // Create a program with a null trace (discard trace output)
    let mut program: Program<CBNCache> = Program::new_from_source(source, "<ffi>", std::io::sink())
        .map_err(|e| format!("Parse error: {}", e))?;

    // Evaluate the program fully for export
    let result = program
        .eval_full_for_export()
        .map_err(|e| program.report_as_str(e))?;

    // Serialize to JSON
    serialize::to_string(ExportFormat::Json, &result)
        .map_err(|e| format!("Serialization error: {:?}", e))
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
            // Should not crash
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
            // JSON output should have the fields
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
            // JSON output is pretty-printed, so check for presence of elements
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
    fn test_eval_internal() {
        // Test the internal eval_nickel function directly
        let result = eval_nickel("42").unwrap();
        assert_eq!(result, "42");

        let result = eval_nickel("{ a = 1 }").unwrap();
        assert!(result.contains("\"a\""));
        assert!(result.contains("1"));
    }
}
