// Copyright (C) 2011  Internet Systems Consortium, Inc. ("ISC")
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND ISC DISCLAIMS ALL WARRANTIES WITH
// REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
// AND FITNESS.  IN NO EVENT SHALL ISC BE LIABLE FOR ANY SPECIAL, DIRECT,
// INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
// LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
// OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
// PERFORMANCE OF THIS SOFTWARE.

#include "factory.h"

#include "data_source.h"
#include "database.h"
#include "sqlite3_accessor.h"
#include "memory_datasrc.h"

#include <dlfcn.h>

using namespace isc::data;
using namespace isc::datasrc;

namespace isc {
namespace datasrc {


DLHolder::DLHolder(const std::string& name) : ds_name_(name) {
    ds_lib_ = dlopen(ds_name_.c_str(), RTLD_NOW | RTLD_LOCAL);
    if (ds_lib_ == NULL) {
        isc_throw(DataSourceError, "Unable to load " << ds_name_ <<
                  ": " << dlerror());
    }
}

DLHolder::~DLHolder() {
    dlclose(ds_lib_);
}

void*
DLHolder::getSym(const char* name) {
    // Since dlsym can return NULL on success, we check for errors by
    // first clearing any existing errors with dlerror(), then calling dlsym,
    // and finally checking for errors with dlerror()
    dlerror();

    void *sym = dlsym(ds_lib_, name);

    const char* dlsym_error = dlerror();
    if (dlsym_error != NULL) {
        dlclose(ds_lib_);
        isc_throw(DataSourceError, "Error in library " << ds_name_ <<
                  ": " << dlsym_error);
    }

    return (sym);
}

DataSourceClientContainer::DataSourceClientContainer(const std::string& type,
                                                     ConstElementPtr config)
: ds_lib_(type + "_ds.so")
{
    ds_creator* ds_create = (ds_creator*)ds_lib_.getSym("createInstance");
    destructor_ = (ds_destructor*)ds_lib_.getSym("destroyInstance");

    instance_ = ds_create(config);
}

DataSourceClientContainer::~DataSourceClientContainer() {
    destructor_(instance_);
}

} // end namespace datasrc
} // end namespace isc

