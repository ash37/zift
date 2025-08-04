// app/javascript/controllers/index.js

// This file should NOT be manually edited. It is updated by running:
// ./bin/rails stimulus:manifest:update

// We've changed the import path from a relative path ("./application")
// to an absolute path based on the importmap ("controllers/application").
// This helps the browser correctly resolve the location of the file.
import { application } from "controllers/application"

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
